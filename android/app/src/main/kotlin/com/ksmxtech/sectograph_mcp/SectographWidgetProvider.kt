package com.ksmxtech.sectograph_mcp

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.text.TextPaint
import android.text.TextUtils
import android.widget.RemoteViews
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import org.json.JSONArray

internal data class NativeSectorEvent(
    val id: String,
    val title: String,
    val start: Long,
    val end: Long,
    val color: Int,
    val subtasks: List<String>
)

/**
 * Android Home Screen Widget Provider for Radian / Sectograph.
 *
 * Implements high-precision real-time minute-by-minute clock needle rotation
 * and dynamic center clock updates via lightweight native Canvas composition (<2ms).
 */
class SectographWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            updateAll(context)
        } catch (_: Exception) {}
        finally {
            scheduleNextMinuteAlarm(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_MINUTE_TICK,
            Intent.ACTION_TIME_TICK,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_USER_PRESENT,
            Intent.ACTION_SCREEN_ON -> {
                try {
                    updateAll(context)
                } catch (_: Exception) {}
                finally {
                    scheduleNextMinuteAlarm(context)
                }
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        try {
            updateAll(context)
        } catch (_: Exception) {}
        finally {
            scheduleNextMinuteAlarm(context)
        }
    }

    companion object {
        const val PREFS_NAME = "sectograph_widget_prefs"
        const val KEY_TITLE = "title"
        const val KEY_TIME = "time"
        const val KEY_STATUS = "status"
        const val KEY_DATE = "date"
        const val KEY_IS_24_HOUR = "is24HourMode"
        const val KEY_DIAL_BG_COLOR = "dialBgColor"
        const val KEY_EVENTS_JSON = "eventsJson"
        const val KEY_BASE_TIMESTAMP = "baseTimestamp"
        const val KEY_BASE_DATE = "baseDate"
        const val MAX_BASE_BITMAP_AGE_MS = 45 * 60 * 1000L // 45 minutes
        const val ACTION_ADD_BLOCK = "com.ksmxtech.sectograph_mcp.ACTION_ADD_BLOCK"
        const val ACTION_MINUTE_TICK = "com.ksmxtech.sectograph_mcp.ACTION_MINUTE_TICK"

        fun scheduleNextMinuteAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, SectographWidgetProvider::class.java).apply {
                action = ACTION_MINUTE_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val now = System.currentTimeMillis()
            val nextMinute = (now / 60000 + 1) * 60000
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
                    } else {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
                }
            } catch (_: Exception) {
                try {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
                } catch (_: Exception) {}
            }
        }

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SectographWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds == null || appWidgetIds.isEmpty()) return

            val compositeBitmap = renderCompositeDial(context) ?: return

            for (appWidgetId in appWidgetIds) {
                updateAppWidgetWithBitmap(context, appWidgetManager, appWidgetId, compositeBitmap)
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val compositeBitmap = renderCompositeDial(context) ?: return
            updateAppWidgetWithBitmap(context, appWidgetManager, appWidgetId, compositeBitmap)
        }

        private fun updateAppWidgetWithBitmap(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            bitmap: Bitmap
        ) {
            val views = RemoteViews(context.packageName, R.layout.sectograph_widget)
            views.setImageViewBitmap(R.id.widget_dial_image, bitmap)

            // Tap anywhere on the circular dial widget -> Open App to Today's Dial
            val openAppIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("radian://today"),
                context,
                MainActivity::class.java
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        /**
         * Composites the base schedule sector dial image with the real-time minute needle
         * and live center clock face in pure native Android Canvas.
         */
        fun renderCompositeDial(context: Context): Bitmap? {
            val baseFile = File(context.filesDir, "widget_dial_base.png")
            val fallbackFile = File(context.filesDir, "widget_dial.png")
            val targetFile = if (baseFile.exists() && baseFile.canRead()) {
                baseFile
            } else if (fallbackFile.exists() && fallbackFile.canRead()) {
                fallbackFile
            } else {
                null
            }

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val is24HourMode = prefs.getBoolean(KEY_IS_24_HOUR, false)
            val dialBgColor = prefs.getInt(KEY_DIAL_BG_COLOR, Color.parseColor("#0F172A"))
            val nowMs = System.currentTimeMillis()
            val isStale = isBitmapStale(targetFile, prefs, nowMs)

            val baseBitmap = if (targetFile != null && !isStale) {
                try {
                    val decodeOptions = BitmapFactory.Options().apply {
                        inPreferredConfig = Bitmap.Config.ARGB_8888
                        inScaled = false
                    }
                    BitmapFactory.decodeFile(targetFile.absolutePath, decodeOptions)
                } catch (_: Exception) {
                    null
                }
            } else {
                null
            }

            val width = baseBitmap?.width ?: 720
            val height = baseBitmap?.height ?: 720
            val compositeBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(compositeBitmap)

            val centerX = width / 2f
            val centerY = height / 2f
            val scale = width / 360f

            val maxRadius = (Math.min(width, height) / 2f) - 4f * scale
            val baseRadius = maxRadius
            val innerRadius = baseRadius * 0.44f // Matches AppLayoutConstants.innerRadiusRatio

            if (baseBitmap != null) {
                canvas.drawBitmap(baseBitmap, 0f, 0f, null)
            } else {
                drawDynamicSectors(canvas, centerX, centerY, baseRadius, innerRadius, scale, nowMs, is24HourMode, dialBgColor, prefs)
            }

            // 1. Clear / Refresh Center Hub Circle
            val hubFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (dialBgColor != 0) dialBgColor else Color.parseColor("#0F172A")
                style = Paint.Style.FILL
            }
            canvas.drawCircle(centerX, centerY, innerRadius - 1f, hubFillPaint)

            val hubBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#374151")
                style = Paint.Style.STROKE
                strokeWidth = 1.0f * scale
            }
            canvas.drawCircle(centerX, centerY, innerRadius, hubBorderPaint)

            // 2. Real-Time Minute Angle & Crimson Needle
            val cal = Calendar.getInstance()
            val hour12 = cal.get(Calendar.HOUR)
            val hour24 = cal.get(Calendar.HOUR_OF_DAY)
            val minute = cal.get(Calendar.MINUTE)
            val second = cal.get(Calendar.SECOND)

            // 12 o'clock corresponds to -90 degrees from positive X axis
            val minuteFraction = (minute + second / 60f) / 60f
            val angleDeg = if (is24HourMode) {
                ((hour24 + minuteFraction) / 24f) * 360f - 90f
            } else {
                ((hour12 + minuteFraction) / 12f) * 360f - 90f
            }
            val angleRad = Math.toRadians(angleDeg.toDouble())
            val cosA = Math.cos(angleRad).toFloat()
            val sinA = Math.sin(angleRad).toFloat()

            val beaconRadius = 6.5f * scale
            val beaconDist = baseRadius - beaconRadius - 4.5f * scale

            val startX = centerX + innerRadius * cosA
            val startY = centerY + innerRadius * sinA
            val endX = centerX + beaconDist * cosA
            val endY = centerY + beaconDist * sinA

            val needlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#EF4444") // Crimson #EF4444
                strokeWidth = 3.0f * scale
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
            }
            canvas.drawLine(startX, startY, endX, endY, needlePaint)

            val beaconBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#EF4444")
                style = Paint.Style.FILL
            }
            canvas.drawCircle(endX, endY, beaconRadius, beaconBgPaint)

            val beaconBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                strokeWidth = 1.2f * scale
                style = Paint.Style.STROKE
            }
            canvas.drawCircle(endX, endY, beaconRadius, beaconBorderPaint)

            // Celestial Icon (Sun pip during daytime 6am-6pm, Moon pip at night)
            val isDaytime = hour24 in 6..17
            val pipPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                style = Paint.Style.FILL
            }
            if (isDaytime) {
                canvas.drawCircle(endX, endY, 2.6f * scale, pipPaint)
            } else {
                canvas.drawCircle(endX, endY, 2.0f * scale, pipPaint)
            }

            // 3. Evaluate Active / Next Event for Current Minute
            var activeTitle: String? = null
            var activeColor: Int = Color.parseColor("#38BDF8")

            val eventsJsonStr = prefs.getString(KEY_EVENTS_JSON, null)
            if (!eventsJsonStr.isNullOrEmpty()) {
                try {
                    val arr = JSONArray(eventsJsonStr)
                    var nearestUpcomingTitle: String? = null
                    var nearestUpcomingDiff = Long.MAX_VALUE
                    var nearestUpcomingColor = activeColor

                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        val start = obj.getLong("start")
                        val end = obj.getLong("end")
                        val title = obj.getString("title")
                        val colorVal = obj.optLong("color", -1L)
                        val color = if (colorVal != -1L) colorVal.toInt() else activeColor

                        if (nowMs in start until end) {
                            activeTitle = title
                            activeColor = color
                            break
                        } else if (start > nowMs) {
                            val diff = start - nowMs
                            if (diff < nearestUpcomingDiff) {
                                nearestUpcomingDiff = diff
                                nearestUpcomingTitle = title
                                nearestUpcomingColor = color
                            }
                        }
                    }

                    if (activeTitle == null && nearestUpcomingTitle != null && nearestUpcomingDiff <= 12 * 3600 * 1000L) {
                        activeTitle = nearestUpcomingTitle
                        activeColor = nearestUpcomingColor
                    }
                } catch (_: Exception) {}
            }

            if (activeTitle == null) {
                val savedTitle = prefs.getString(KEY_TITLE, null)
                if (!savedTitle.isNullOrEmpty() && savedTitle != "Dial is clear") {
                    activeTitle = savedTitle
                }
            }

            // 4. Center Clock Face Typography (Exact 1:1 Parity with SectographPainter)
            val timeFontSize = innerRadius * 0.38f
            val dateFontSize = innerRadius * 0.16f
            val amPmFontSize = innerRadius * 0.18f
            val chipFontSize = innerRadius * 0.125f

            val amPmStr = if (cal.get(Calendar.AM_PM) == Calendar.AM) "AM" else "PM"
            val timeFormat = if (is24HourMode) {
                SimpleDateFormat("HH:mm", Locale.getDefault())
            } else {
                SimpleDateFormat("h:mm", Locale.getDefault())
            }
            val timeStr = timeFormat.format(cal.time)
            val dateFormat = SimpleDateFormat("EEE, d MMM", Locale.getDefault())
            val dateStr = dateFormat.format(cal.time)

            val hasAmPm = !is24HourMode
            val hasChip = !activeTitle.isNullOrEmpty()

            val amPmPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#38BDF8") // Sky accent
                textSize = amPmFontSize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val timePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = timeFontSize
                typeface = Typeface.create("sans-serif-black", Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val datePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#9CA3AF")
                textSize = dateFontSize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }

            val amPmH = if (hasAmPm) amPmFontSize else 0f
            val timeH = timeFontSize * 0.85f
            val dateH = dateFontSize
            val chipH = if (hasChip) chipFontSize * 1.8f else 0f

            val gapAmPm = if (hasAmPm) 3.5f * scale else 0f
            val gapDate = 4.5f * scale
            val gapChip = if (hasChip) 6.0f * scale else 0f

            val totalH = amPmH + gapAmPm + timeH + gapDate + dateH + gapChip + chipH
            var curY = centerY - totalH / 2f

            if (hasAmPm) {
                curY += amPmH
                canvas.drawText(amPmStr, centerX, curY, amPmPaint)
                curY += gapAmPm
            }

            curY += timeH
            canvas.drawText(timeStr, centerX, curY, timePaint)
            curY += gapDate

            curY += dateH
            canvas.drawText(dateStr, centerX, curY, datePaint)
            curY += gapChip

            if (hasChip && activeTitle != null) {
                val chipTextPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.WHITE
                    textSize = chipFontSize
                    typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                    textAlign = Paint.Align.CENTER
                }
                val maxChipTextW = innerRadius * 1.15f
                val ellipsized = TextUtils.ellipsize(
                    activeTitle,
                    chipTextPaint,
                    maxChipTextW,
                    TextUtils.TruncateAt.END
                ).toString()
                val textW = chipTextPaint.measureText(ellipsized)

                val chipPaddingH = 8f * scale
                val chipRectW = (textW + chipPaddingH * 2).coerceAtMost(innerRadius * 1.4f)
                val chipRectH = chipH

                val chipLeft = centerX - chipRectW / 2f
                val chipTop = curY
                val chipRight = centerX + chipRectW / 2f
                val chipBottom = curY + chipRectH
                val chipRRect = RectF(chipLeft, chipTop, chipRight, chipBottom)

                val r = Color.red(activeColor)
                val g = Color.green(activeColor)
                val b = Color.blue(activeColor)

                val chipBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(60, r, g, b)
                    style = Paint.Style.FILL
                }
                val chipBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(130, r, g, b)
                    strokeWidth = 1.0f * scale
                    style = Paint.Style.STROKE
                }

                val cornerRadius = 8f * scale
                canvas.drawRoundRect(chipRRect, cornerRadius, cornerRadius, chipBgPaint)
                canvas.drawRoundRect(chipRRect, cornerRadius, cornerRadius, chipBorderPaint)

                val textY = chipTop + (chipRectH / 2f) - ((chipTextPaint.descent() + chipTextPaint.ascent()) / 2f)
                canvas.drawText(ellipsized, centerX, textY, chipTextPaint)
            }

            return compositeBitmap
        }

        private fun isBitmapStale(targetFile: File?, prefs: SharedPreferences, nowMs: Long): Boolean {
            if (targetFile == null || !targetFile.exists() || !targetFile.canRead()) return true

            val baseTimestamp = prefs.getLong(KEY_BASE_TIMESTAMP, 0L)
            val baseDate = prefs.getString(KEY_BASE_DATE, null)
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(nowMs))

            // 1. Calendar day rollover check (e.g. Monday night -> Tuesday morning)
            if (baseDate != null && baseDate != todayStr) {
                return true
            }

            // 2. Age check (stale if older than 45 minutes)
            val age = if (baseTimestamp > 0L) {
                nowMs - baseTimestamp
            } else {
                nowMs - targetFile.lastModified()
            }

            return age > MAX_BASE_BITMAP_AGE_MS || age < 0L
        }

        private fun drawDynamicSectors(
            canvas: Canvas,
            centerX: Float,
            centerY: Float,
            baseRadius: Float,
            innerRadius: Float,
            scale: Float,
            nowMs: Long,
            is24HourMode: Boolean,
            dialBgColor: Int,
            prefs: SharedPreferences
        ) {
            // 1. Dial Background Chassis
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (dialBgColor != 0) dialBgColor else Color.parseColor("#0B0F19")
                style = Paint.Style.FILL
            }
            canvas.drawCircle(centerX, centerY, baseRadius, bgPaint)

            // Radial hour division spokes (12 or 24)
            val totalHours = if (is24HourMode) 24 else 12
            val stepDeg = 360f / totalHours
            val spokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#1F2937")
                strokeWidth = 1.0f * scale
            }
            for (h in 0 until totalHours) {
                val rad = Math.toRadians((h * stepDeg - 90f).toDouble())
                val x1 = centerX + innerRadius * Math.cos(rad).toFloat()
                val y1 = centerY + innerRadius * Math.sin(rad).toFloat()
                val x2 = centerX + (baseRadius - 8f * scale) * Math.cos(rad).toFloat()
                val y2 = centerY + (baseRadius - 8f * scale) * Math.sin(rad).toFloat()
                canvas.drawLine(x1, y1, x2, y2, spokePaint)
            }

            // 2. Parse and Filter Events from eventsJson
            val eventsJsonStr = prefs.getString(KEY_EVENTS_JSON, null)
            val allEvents = mutableListOf<NativeSectorEvent>()
            if (!eventsJsonStr.isNullOrEmpty()) {
                try {
                    val arr = JSONArray(eventsJsonStr)
                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        val id = obj.optString("id", i.toString())
                        val title = obj.optString("title", "")
                        val start = obj.optLong("start", 0L)
                        val end = obj.optLong("end", 0L)
                        val colorVal = obj.optLong("color", -1L)
                        val color = if (colorVal != -1L) colorVal.toInt() else Color.parseColor("#38BDF8")
                        val subtasks = mutableListOf<String>()
                        val subtasksArr = obj.optJSONArray("subtasks")
                        if (subtasksArr != null) {
                            for (s in 0 until subtasksArr.length()) {
                                val st = subtasksArr.optString(s)
                                if (st.isNotEmpty()) subtasks.add(st)
                            }
                        }
                        if (end > start && title.isNotEmpty()) {
                            allEvents.add(NativeSectorEvent(id, title, start, end, color, subtasks))
                        }
                    }
                } catch (_: Exception) {}
            }

            // 3. Rolling Horizon Selection (1 past block, 1 active block, upcoming blocks within 12 hours)
            val horizonEvents = mutableListOf<NativeSectorEvent>()
            val activeEvent = allEvents.firstOrNull { nowMs in it.start until it.end }
            val pastEvents = allEvents.filter { it.end <= nowMs && (nowMs - it.end) <= 3 * 3600 * 1000L }
                .sortedByDescending { it.end }
            val upcomingEvents = allEvents.filter { it.start >= nowMs && (it.start - nowMs) <= 12 * 3600 * 1000L }
                .sortedBy { it.start }

            if (pastEvents.isNotEmpty()) {
                horizonEvents.add(pastEvents.first())
            }
            if (activeEvent != null) {
                horizonEvents.add(activeEvent)
            }
            horizonEvents.addAll(upcomingEvents.take(3))

            // 4. Draw Sector Arcs, Dividers, and Labels
            val rIn = innerRadius + 2f * scale
            val rOut = baseRadius - 6f * scale
            val strokeW = rOut - rIn
            val midR = (rIn + rOut) / 2f
            val sectorRect = RectF(centerX - midR, centerY - midR, centerX + midR, centerY + midR)

            val rate = if (is24HourMode) 0.25f else 0.5f

            for (event in horizonEvents) {
                val cal = Calendar.getInstance().apply { timeInMillis = event.start }
                val h = if (is24HourMode) cal.get(Calendar.HOUR_OF_DAY) else cal.get(Calendar.HOUR)
                val m = cal.get(Calendar.MINUTE)
                val s = cal.get(Calendar.SECOND)
                val dialDeg = ((h * 60 + m + s / 60f) * rate) % 360f
                val canvasStartDeg = dialDeg - 90f

                val durMin = (event.end - event.start) / (60f * 1000f)
                val sweepDeg = (durMin * rate).coerceAtLeast(4.0f).coerceAtMost(360f)

                val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = event.color
                    style = Paint.Style.STROKE
                    strokeWidth = strokeW
                    strokeCap = Paint.Cap.BUTT
                }
                canvas.drawArc(sectorRect, canvasStartDeg, sweepDeg, false, arcPaint)

                // Draw sector boundary divider gaps
                val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (dialBgColor != 0) dialBgColor else Color.parseColor("#0B0F19")
                    strokeWidth = 2.0f * scale
                    style = Paint.Style.STROKE
                }
                val sRad = Math.toRadians(canvasStartDeg.toDouble())
                canvas.drawLine(
                    centerX + rIn * Math.cos(sRad).toFloat(),
                    centerY + rIn * Math.sin(sRad).toFloat(),
                    centerX + rOut * Math.cos(sRad).toFloat(),
                    centerY + rOut * Math.sin(sRad).toFloat(),
                    divPaint
                )
                val eRad = Math.toRadians((canvasStartDeg + sweepDeg).toDouble())
                canvas.drawLine(
                    centerX + rIn * Math.cos(eRad).toFloat(),
                    centerY + rIn * Math.sin(eRad).toFloat(),
                    centerX + rOut * Math.cos(eRad).toFloat(),
                    centerY + rOut * Math.sin(eRad).toFloat(),
                    divPaint
                )

                // Sector Title Typography (centered at midpoint angle, flipped tangentially for legibility)
                if (sweepDeg >= 12f) {
                    val midAngleDeg = canvasStartDeg + sweepDeg / 2f
                    val midRad = Math.toRadians(midAngleDeg.toDouble())
                    val posX = centerX + midR * Math.cos(midRad).toFloat()
                    val posY = centerY + midR * Math.sin(midRad).toFloat()

                    val keyword = distillShortKeyword(event.title)
                    val lum = (0.299 * Color.red(event.color) + 0.587 * Color.green(event.color) + 0.114 * Color.blue(event.color)) / 255.0
                    val textColor = if (lum > 0.55) Color.parseColor("#1E1A16") else Color.WHITE

                    val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = textColor
                        textSize = (strokeW * 0.28f).coerceIn(9f * scale, 13f * scale)
                        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                        textAlign = Paint.Align.CENTER
                    }

                    canvas.save()
                    canvas.translate(posX, posY)
                    var tangentRad = midRad + Math.PI / 2.0
                    if (Math.cos(tangentRad) < 0.05) {
                        tangentRad += Math.PI
                    }
                    canvas.rotate(Math.toDegrees(tangentRad).toFloat())

                    val hasSubtasks = event.subtasks.isNotEmpty() && sweepDeg >= 30f
                    if (hasSubtasks) {
                        val titleBaselineY = -4f * scale
                        canvas.drawText(keyword, 0f, titleBaselineY, textPaint)

                        val subtaskPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = textColor
                            textSize = (strokeW * 0.18f).coerceIn(7f * scale, 9.5f * scale)
                            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
                            textAlign = Paint.Align.CENTER
                            alpha = if (lum > 0.55) 200 else 220
                        }
                        val subtaskSummary = event.subtasks.take(2).joinToString(" • ")
                        val subtaskBaselineY = 8f * scale
                        canvas.drawText(subtaskSummary, 0f, subtaskBaselineY, subtaskPaint)
                    } else {
                        val textBaselineY = -(textPaint.descent() + textPaint.ascent()) / 2f
                        canvas.drawText(keyword, 0f, textBaselineY, textPaint)
                    }

                    canvas.restore()
                }
            }

            // 5. Outer Bezel Outline
            val outlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#374151")
                style = Paint.Style.STROKE
                strokeWidth = 1.2f * scale
            }
            canvas.drawCircle(centerX, centerY, baseRadius, outlinePaint)

            // 6. Minor Interval Ticks (48 intervals)
            val tickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#4B5563")
                strokeWidth = 1.0f * scale
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
            }
            val intervals = 48
            for (i in 0 until intervals) {
                if (i % 4 == 0) continue // Hour numerals sit here
                val deg = (i / intervals.toFloat()) * 360f - 90f
                val rad = Math.toRadians(deg.toDouble())
                val tickLen = if (i % 2 == 0) 3.5f * scale else 2.0f * scale
                val x1 = centerX + baseRadius * Math.cos(rad).toFloat()
                val y1 = centerY + baseRadius * Math.sin(rad).toFloat()
                val x2 = centerX + (baseRadius - tickLen) * Math.cos(rad).toFloat()
                val y2 = centerY + (baseRadius - tickLen) * Math.sin(rad).toFloat()
                canvas.drawLine(x1, y1, x2, y2, tickPaint)
            }

            // 7. 3D Hour Numerals (12, 1, 2, ..., 11)
            val numPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#D1D5DB")
                textSize = 9.0f * scale
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val numRadius = baseRadius - 4.5f * scale
            val hourCount = if (is24HourMode) 24 else 12
            val stepHours = if (is24HourMode) 2 else 1
            for (h in 0 until hourCount step stepHours) {
                val numStr = if (is24HourMode) h.toString() else (if (h == 0) "12" else h.toString())
                val deg = (h / hourCount.toFloat()) * 360f - 90f
                val rad = Math.toRadians(deg.toDouble())
                val nx = centerX + numRadius * Math.cos(rad).toFloat()
                val ny = centerY + numRadius * Math.sin(rad).toFloat()
                val numBaselineY = ny - ((numPaint.descent() + numPaint.ascent()) / 2f)
                canvas.drawText(numStr, nx, numBaselineY, numPaint)
            }
        }

        private fun distillShortKeyword(text: String): String {
            val clean = text.trim()
            if (clean.isEmpty()) return ""
            val lower = clean.lowercase(Locale.getDefault())
            if (lower.contains("linear algebra") || lower.contains("linalg")) return "LinAlg"
            if (lower.contains("transformer")) return "Transformers"
            if (lower.contains("flexible")) return "Flex"
            if (lower.contains("lunch")) return "Lunch"
            if (lower.contains("dinner")) return "Dinner"
            if (lower.contains("workout")) return "Workout"
            if (lower.contains("project")) return "Projects"
            if (lower.contains("study")) return "Study"
            if (lower.contains("sleep")) return "Sleep"
            if (lower.contains("nap")) return "Nap"

            val sanitized = clean.replace(Regex("""[+\-:|()]+"""), " ").trim()
            if (sanitized.length <= 10) return sanitized
            val words = sanitized.split(Regex("""\s+""")).filter { it.isNotEmpty() }
            if (words.isEmpty()) return clean
            return if (words[0].length > 10) words[0].substring(0, 9) else words[0]
        }
    }
}
