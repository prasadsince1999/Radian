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
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.Rect
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
    val subtasks: List<String>,
    val iconName: String? = null
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
        const val KEY_ACTIVE_EVENT_END = "activeEventEnd"
        const val KEY_FOCUS_ANGLE = "focusAngle"
        const val KEY_MAGNIFICATION = "magnification"
        const val KEY_LENS_ENABLED = "isFocusLensEnabled"
        const val KEY_CENTER_CLOCK_DISPLAY = "centerClockDisplay"
        const val KEY_INNER_RADIUS_RATIO = "innerRadiusRatio"
        const val KEY_PREVIOUS_BLOCKS_COUNT = "previousBlocksCount"
        const val KEY_FUTURE_BLOCKS_COUNT = "futureBlocksCount"
        const val MAX_IDLE_BITMAP_AGE_MS = 12 * 3600 * 1000L // 12 hours (full dial cycle)
        const val ACTION_ADD_BLOCK = "com.ksmxtech.sectograph_mcp.ACTION_ADD_BLOCK"
        const val ACTION_MINUTE_TICK = "com.ksmxtech.sectograph_mcp.ACTION_MINUTE_TICK"

        private fun normalizeDegrees(deg: Double): Double {
            var d = deg % 360.0
            if (d < 0.0) d += 360.0
            return d
        }

        private fun normalizeDelta(deg: Double): Double {
            var d = deg % 360.0
            if (d > 180.0) d -= 360.0
            if (d < -180.0) d += 360.0
            return d
        }

        private fun warpAngle(angleDeg: Double, focusAngle: Double, magnification: Double): Double {
            if (Math.abs(magnification - 1.0) <= 0.001) {
                return normalizeDegrees(angleDeg)
            }
            val normalized = normalizeDegrees(angleDeg)
            val diff = normalizeDelta(normalized - focusAngle)
            val x = diff / 180.0

            val absX = Math.abs(x)
            val warpedX = (magnification * x) / (1.0 + (magnification - 1.0) * absX)
            val warpedDiff = warpedX * 180.0
            return normalizeDegrees(focusAngle + warpedDiff)
        }

        private fun isColorDark(color: Int): Boolean {
            val darkness = 1 - (0.299 * Color.red(color) + 0.587 * Color.green(color) + 0.114 * Color.blue(color)) / 255.0
            return darkness >= 0.5
        }

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

            val width = baseBitmap?.width ?: 1080
            val height = baseBitmap?.height ?: 1080
            val compositeBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(compositeBitmap)

            val centerX = width / 2f
            val centerY = height / 2f
            val scale = width / 360f

            val maxRadius = (Math.min(width, height) / 2f) - 4f * scale
            val baseRadius = maxRadius
            val innerRadiusRatio = prefs.getFloat(KEY_INNER_RADIUS_RATIO, 0.34f)
            val innerRadius = baseRadius * innerRadiusRatio

            val isLensEnabled = prefs.getBoolean(KEY_LENS_ENABLED, true)
            val storedFocusAngle = prefs.getFloat(KEY_FOCUS_ANGLE, -1f)
            val storedMagnification = prefs.getFloat(KEY_MAGNIFICATION, 1.0f)

            var dynamicFocusAngle = storedFocusAngle
            var dynamicMagnification = storedMagnification

            val eventsJsonStr = prefs.getString(KEY_EVENTS_JSON, null)
            val rate = if (is24HourMode) 0.25f else 0.5f

            if (!eventsJsonStr.isNullOrEmpty()) {
                try {
                    val arr = JSONArray(eventsJsonStr)
                    val todayCal = Calendar.getInstance().apply { timeInMillis = nowMs }
                    val tYear = todayCal.get(Calendar.YEAR)
                    val tMonth = todayCal.get(Calendar.MONTH)
                    val tDay = todayCal.get(Calendar.DAY_OF_MONTH)

                    var currentActiveObj: org.json.JSONObject? = null
                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        val rawStart = obj.optLong("start", 0L)
                        val rawEnd = obj.optLong("end", 0L)
                        if (rawEnd > rawStart) {
                            val evCal = Calendar.getInstance().apply { timeInMillis = rawStart }
                            val sHour = evCal.get(Calendar.HOUR_OF_DAY)
                            val sMin = evCal.get(Calendar.MINUTE)
                            val durMs = rawEnd - rawStart
                            val pCal = Calendar.getInstance().apply {
                                set(Calendar.YEAR, tYear)
                                set(Calendar.MONTH, tMonth)
                                set(Calendar.DAY_OF_MONTH, tDay)
                                set(Calendar.HOUR_OF_DAY, sHour)
                                set(Calendar.MINUTE, sMin)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }
                            val start = pCal.timeInMillis
                            val end = start + durMs
                            if (nowMs in start until end) {
                                currentActiveObj = obj
                                break
                            }
                        }
                    }

                    if (currentActiveObj != null) {
                        val rawStart = currentActiveObj.optLong("start", 0L)
                        val rawEnd = currentActiveObj.optLong("end", 0L)
                        val durMs = rawEnd - rawStart
                        val midMs = rawStart + durMs / 2
                        val midCal = Calendar.getInstance().apply { timeInMillis = midMs }
                        val h = if (is24HourMode) midCal.get(Calendar.HOUR_OF_DAY) else (midCal.get(Calendar.HOUR) % 12)
                        val m = midCal.get(Calendar.MINUTE)
                        val s = midCal.get(Calendar.SECOND)
                        dynamicFocusAngle = ((h * 60 + m + s / 60f) * rate) % 360f
                        val subtasksArr = currentActiveObj.optJSONArray("subtasks")
                        val hasSubtasks = subtasksArr != null && subtasksArr.length() > 0
                        dynamicMagnification = if (hasSubtasks) 2.05f else 1.75f
                    } else {
                        // Linear dial in gaps
                        dynamicFocusAngle = -1f
                        dynamicMagnification = 1.0f
                    }
                } catch (_: Exception) {}
            }

            if (baseBitmap != null) {
                val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
                    isDither = true
                }
                if (baseBitmap.width == width && baseBitmap.height == height) {
                    canvas.drawBitmap(baseBitmap, 0f, 0f, bitmapPaint)
                } else {
                    val srcRect = Rect(0, 0, baseBitmap.width, baseBitmap.height)
                    val dstRect = RectF(0f, 0f, width.toFloat(), height.toFloat())
                    canvas.drawBitmap(baseBitmap, srcRect, dstRect, bitmapPaint)
                }
                try {
                    baseBitmap.recycle()
                } catch (_: Exception) {}
            } else {
                drawDynamicSectors(
                    context, canvas, centerX, centerY, baseRadius, innerRadius, scale, nowMs,
                    is24HourMode, dialBgColor, prefs, dynamicFocusAngle, dynamicMagnification, isLensEnabled
                )
            }

            // 1. Clear / Refresh Center Hub Circle
            val isDarkDial = isColorDark(if (dialBgColor != 0) dialBgColor else Color.parseColor("#0F172A"))
            val hubFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (dialBgColor != 0) dialBgColor else (if (isDarkDial) Color.parseColor("#0F172A") else Color.WHITE)
                style = Paint.Style.FILL
            }
            canvas.drawCircle(centerX, centerY, innerRadius - 1f, hubFillPaint)

            val hubBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (isDarkDial) Color.parseColor("#374151") else Color.parseColor("#E2E8F0")
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
            val dialDeg = if (is24HourMode) {
                ((hour24 + minuteFraction) / 24f) * 360f
            } else {
                ((hour12 + minuteFraction) / 12f) * 360f
            }

            val effectiveFocusAngle = if (baseBitmap != null) storedFocusAngle else dynamicFocusAngle
            val effectiveMagnification = if (baseBitmap != null) storedMagnification else dynamicMagnification

            val warpedDialDeg = if (isLensEnabled && effectiveFocusAngle >= 0f && effectiveMagnification > 1.001f) {
                warpAngle(dialDeg.toDouble(), effectiveFocusAngle.toDouble(), effectiveMagnification.toDouble()).toFloat()
            } else {
                dialDeg
            }
            val angleDeg = warpedDialDeg - 90f
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

            if (!eventsJsonStr.isNullOrEmpty()) {
                try {
                    val arr = JSONArray(eventsJsonStr)
                    var nearestUpcomingTitle: String? = null
                    var nearestUpcomingDiff = Long.MAX_VALUE
                    var nearestUpcomingColor = activeColor

                    val todayCal = Calendar.getInstance().apply { timeInMillis = nowMs }
                    val tYear = todayCal.get(Calendar.YEAR)
                    val tMonth = todayCal.get(Calendar.MONTH)
                    val tDay = todayCal.get(Calendar.DAY_OF_MONTH)

                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        val rawStart = obj.getLong("start")
                        val rawEnd = obj.getLong("end")
                        val title = obj.getString("title")
                        val colorVal = obj.optLong("color", -1L)
                        val color = if (colorVal != -1L) colorVal.toInt() else activeColor

                        val evCal = Calendar.getInstance().apply { timeInMillis = rawStart }
                        val sHour = evCal.get(Calendar.HOUR_OF_DAY)
                        val sMin = evCal.get(Calendar.MINUTE)
                        val durMs = rawEnd - rawStart

                        val pCal = Calendar.getInstance().apply {
                            set(Calendar.YEAR, tYear)
                            set(Calendar.MONTH, tMonth)
                            set(Calendar.DAY_OF_MONTH, tDay)
                            set(Calendar.HOUR_OF_DAY, sHour)
                            set(Calendar.MINUTE, sMin)
                            set(Calendar.SECOND, 0)
                            set(Calendar.MILLISECOND, 0)
                        }
                        val start = pCal.timeInMillis
                        val end = start + durMs

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

            // 4. Center Clock Face Typography (Exact 1:1 Parity with Flutter SectographPainter)
            val centerClockDisplay = prefs.getString(KEY_CENTER_CLOCK_DISPLAY, "digital") ?: "digital"
            val isDigitalMode = (centerClockDisplay == "digital")

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
            val hasChip = false

            val isDark = isColorDark(if (dialBgColor != 0) dialBgColor else Color.parseColor("#0F172A"))
            val primaryTextColor = if (isDark) Color.parseColor("#F8FAFC") else Color.parseColor("#0F172A")
            val secondaryTextColor = if (isDark) Color.parseColor("#94A3B8") else Color.parseColor("#64748B")
            val amPmColor = if (isDark) Color.parseColor("#38BDF8") else Color.parseColor("#0284C7")

            val timeFontSize = innerRadius * (if (hasChip) 0.38f else 0.48f)
            val dateFontSize = innerRadius * (if (hasChip) 0.16f else 0.18f)
            val amPmFontSize = innerRadius * 0.19f
            val chipFontSize = innerRadius * 0.125f

            val amPmPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = amPmColor
                textSize = amPmFontSize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val timePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = primaryTextColor
                textSize = timeFontSize
                typeface = Typeface.create("sans-serif-black", Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val datePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = secondaryTextColor
                textSize = dateFontSize
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }

            val amPmH = if (hasAmPm) amPmFontSize else 0f
            val timeH = timeFontSize * 0.85f
            val dateH = dateFontSize
            val chipH = if (hasChip) chipFontSize * 1.8f else 0f

            val gapAmPm = if (hasAmPm) (if (hasChip) 3.0f else 2.0f) * scale else 0f
            val gapDate = (if (hasChip) 4.0f else 3.0f) * scale
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
            val activeEventEnd = prefs.getLong(KEY_ACTIVE_EVENT_END, 0L)
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(nowMs))

            // 1. Calendar day rollover check (e.g. Monday night -> Tuesday morning)
            if (baseDate != null && baseDate != todayStr) {
                return true
            }

            // 2. Active event window check:
            // If an active event was recorded at sync time, the base dial bitmap remains
            // 100% valid and fresh for the ENTIRE duration of that active block!
            if (activeEventEnd > baseTimestamp) {
                if (nowMs in baseTimestamp..activeEventEnd) {
                    return false
                }
                if (nowMs > activeEventEnd) {
                    return true // Active event ended, transition to dynamic sectors
                }
            }

            // 3. Fallback age check for idle / gap times: allow 12 hours (full dial rotation)
            val age = if (baseTimestamp > 0L) {
                nowMs - baseTimestamp
            } else {
                nowMs - targetFile.lastModified()
            }

            return age > MAX_IDLE_BITMAP_AGE_MS || age < 0L
        }

        private var cachedKalamTypeface: Typeface? = null

        private fun getKalamTypeface(context: Context): Typeface {
            if (cachedKalamTypeface != null) return cachedKalamTypeface!!
            return try {
                val tf = Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/Kalam-Bold.ttf")
                cachedKalamTypeface = tf
                tf
            } catch (_: Exception) {
                try {
                    val tf = Typeface.createFromAsset(context.assets, "assets/fonts/Kalam-Bold.ttf")
                    cachedKalamTypeface = tf
                    tf
                } catch (_: Exception) {
                    Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                }
            }
        }

        private fun darkenColor(color: Int, factor: Float = 0.36f): Int {
            val a = Color.alpha(color)
            val r = (Color.red(color) * (1f - factor)).toInt().coerceIn(0, 255)
            val g = (Color.green(color) * (1f - factor)).toInt().coerceIn(0, 255)
            val b = (Color.blue(color) * (1f - factor)).toInt().coerceIn(0, 255)
            return Color.argb(a, r, g, b)
        }

        private var cachedMaterialIconsTypeface: Typeface? = null

        private fun getMaterialIconsTypeface(context: Context): Typeface {
            if (cachedMaterialIconsTypeface != null) return cachedMaterialIconsTypeface!!
            return try {
                val tf = Typeface.createFromAsset(context.assets, "flutter_assets/fonts/MaterialIcons-Regular.otf")
                cachedMaterialIconsTypeface = tf
                tf
            } catch (_: Exception) {
                try {
                    val tf = Typeface.createFromAsset(context.assets, "fonts/MaterialIcons-Regular.otf")
                    cachedMaterialIconsTypeface = tf
                    tf
                } catch (_: Exception) {
                    Typeface.DEFAULT
                }
            }
        }

        private fun getEventIconGlyph(title: String, iconName: String? = null): String {
            if (!iconName.isNullOrEmpty()) {
                val icon = iconName.lowercase(Locale.getDefault())
                when {
                    icon.contains("laptop") || icon.contains("code") || icon.contains("dev") || icon.contains("work") -> return String(Character.toChars(0xf841))
                    icon.contains("restaurant") || icon.contains("food") || icon.contains("dinner") || icon.contains("eat") -> return String(Character.toChars(0xf0108))
                    icon.contains("fitness") || icon.contains("gym") || icon.contains("workout") -> return String(Character.toChars(0xf767))
                    icon.contains("bed") || icon.contains("sleep") || icon.contains("rest") -> return String(Character.toChars(0xf5b8))
                    icon.contains("book") || icon.contains("read") -> return String(Character.toChars(0xf8b4))
                    icon.contains("coffee") || icon.contains("break") -> return String(Character.toChars(0xf655))
                    icon.contains("headphone") || icon.contains("music") -> return String(Character.toChars(0xf7da))
                }
            }
            val lower = title.lowercase(Locale.getDefault())
            val codePoint = when {
                lower.contains("cook") || lower.contains("dinner") || lower.contains("lunch") ||
                lower.contains("eat") || lower.contains("meal") || lower.contains("breakfast") ||
                lower.contains("food") -> 0xf0108 // Icons.restaurant_rounded
                lower.contains("code") || lower.contains("work") || lower.contains("study") ||
                lower.contains("focus") || lower.contains("dev") || lower.contains("project") ||
                lower.contains("flexible") || lower.contains("laptop") -> 0xf841 // Icons.laptop_mac_rounded
                lower.contains("sleep") || lower.contains("bed") || lower.contains("nap") ||
                lower.contains("rest") -> 0xf5b8 // Icons.bedtime_rounded
                lower.contains("workout") || lower.contains("gym") || lower.contains("fitness") ||
                lower.contains("run") || lower.contains("walk") || lower.contains("exercise") ||
                lower.contains("cardio") || lower.contains("sport") -> 0xf767 // Icons.fitness_center_rounded
                lower.contains("break") || lower.contains("coffee") || lower.contains("tea") ||
                lower.contains("chill") -> 0xf655 // Icons.coffee_rounded
                lower.contains("read") || lower.contains("book") || lower.contains("learn") ||
                lower.contains("novel") -> 0xf8b4 // Icons.menu_book_rounded
                lower.contains("chat") || lower.contains("meet") || lower.contains("call") ||
                lower.contains("forum") -> 0xf79d // Icons.forum_rounded
                lower.contains("music") || lower.contains("audio") -> 0xf7da // Icons.headphones_rounded
                else -> 0xf012b // Icons.schedule_rounded
            }
            return String(Character.toChars(codePoint))
        }

        private fun buildPillPath(
            centerX: Float,
            centerY: Float,
            rIn: Float,
            rOut: Float,
            startDialDeg: Float,
            sweepDeg: Float,
            cornerRadius: Float = 6f,
            roundStart: Boolean = true,
            roundEnd: Boolean = true
        ): Path {
            val path = Path()
            if (sweepDeg <= 0.05f) return path

            val endDialDeg = startDialDeg + sweepDeg
            val radialThickness = rOut - rIn
            val maxCornerFromSweep = (rIn * sweepDeg * Math.PI / 180.0).toFloat() / 2.2f
            val actualCornerR = minOf(cornerRadius, minOf(radialThickness * 0.45f, maxCornerFromSweep))
                .coerceIn(1f, 12f)

            val dThOut = (actualCornerR / rOut) * (180f / Math.PI.toFloat())
            val dThIn = (actualCornerR / rIn) * (180f / Math.PI.toFloat())

            fun pt(r: Float, dialDeg: Float): PointF {
                val rad = Math.toRadians((dialDeg - 90.0).toDouble())
                return PointF(
                    centerX + r * Math.cos(rad).toFloat(),
                    centerY + r * Math.sin(rad).toFloat()
                )
            }

            // 1. Start point
            val startOuterDeg = if (roundStart) startDialDeg + dThOut else startDialDeg
            val p0 = pt(rOut, startOuterDeg)
            path.moveTo(p0.x, p0.y)

            // 2. Outer arc
            val sweepOutEnd = if (roundEnd) endDialDeg - dThOut else endDialDeg
            val sweepOut = sweepOutEnd - startOuterDeg
            if (sweepOut > 0f) {
                val outerRect = RectF(centerX - rOut, centerY - rOut, centerX + rOut, centerY + rOut)
                path.arcTo(outerRect, startOuterDeg - 90f, sweepOut, false)
            }

            // 3. Corner 1 (End-Outer)
            if (roundEnd) {
                val corner1Vertex = pt(rOut, endDialDeg)
                val p1 = pt(rOut - actualCornerR, endDialDeg)
                path.quadTo(corner1Vertex.x, corner1Vertex.y, p1.x, p1.y)

                // 4. End edge to inner corner
                val p2 = pt(rIn + actualCornerR, endDialDeg)
                path.lineTo(p2.x, p2.y)

                // 5. Corner 2 (End-Inner)
                val corner2Vertex = pt(rIn, endDialDeg)
                val p3 = pt(rIn, endDialDeg - dThIn)
                path.quadTo(corner2Vertex.x, corner2Vertex.y, p3.x, p3.y)
            } else {
                val pEndInner = pt(rIn, endDialDeg)
                path.lineTo(pEndInner.x, pEndInner.y)
            }

            // 6. Inner arc (drawn counter-clockwise)
            val sweepInStart = if (roundEnd) endDialDeg - dThIn else endDialDeg
            val sweepInEnd = if (roundStart) startDialDeg + dThIn else startDialDeg
            val sweepIn = sweepInStart - sweepInEnd
            if (sweepIn > 0.05f) {
                val innerRect = RectF(centerX - rIn, centerY - rIn, centerX + rIn, centerY + rIn)
                path.arcTo(innerRect, sweepInStart - 90f, -sweepIn, false)
            } else {
                val pEnd = pt(rIn, sweepInEnd)
                path.lineTo(pEnd.x, pEnd.y)
            }

            // 7. Corner 3 (Start-Inner)
            if (roundStart) {
                val corner3Vertex = pt(rIn, startDialDeg)
                val p4 = pt(rIn + actualCornerR, startDialDeg)
                path.quadTo(corner3Vertex.x, corner3Vertex.y, p4.x, p4.y)

                // 8. Start edge to outer corner
                val p5 = pt(rOut - actualCornerR, startDialDeg)
                path.lineTo(p5.x, p5.y)

                // 9. Corner 4 (Start-Outer)
                val corner4Vertex = pt(rOut, startDialDeg)
                path.quadTo(corner4Vertex.x, corner4Vertex.y, p0.x, p0.y)
            } else {
                path.close()
            }

            path.close()
            return path
        }

        private fun drawIntegratedCap(
            canvas: Canvas,
            centerX: Float,
            centerY: Float,
            rIn: Float,
            rOut: Float,
            startDeg: Float,
            sweepDeg: Float,
            timeMs: Long,
            eventColor: Int,
            isStartCap: Boolean,
            is24HourMode: Boolean,
            scale: Float,
            cornerRadius: Float = 6f,
            roundStart: Boolean = false,
            roundEnd: Boolean = true,
            isContiguous: Boolean = false,
            overlapDeg: Float = 0f
        ) {
            if (sweepDeg <= 0.5f) return

            val capPath = buildPillPath(
                centerX, centerY, rIn, rOut,
                startDeg, sweepDeg,
                cornerRadius = cornerRadius,
                roundStart = roundStart,
                roundEnd = roundEnd
            )

            // 3D Overlap drop shadow for contiguous boundary caps
            if (isContiguous && overlapDeg > 0f) {
                val boundaryDeg = (startDeg + sweepDeg) - overlapDeg
                canvas.save()
                val shadowPath = buildPillPath(
                    centerX, centerY, rIn, rOut,
                    boundaryDeg, overlapDeg + 3.2f,
                    cornerRadius = cornerRadius,
                    roundStart = false,
                    roundEnd = true
                )
                val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(90, 0, 0, 0)
                    maskFilter = BlurMaskFilter(3.2f * scale, BlurMaskFilter.Blur.NORMAL)
                }
                canvas.drawPath(shadowPath, shadowPaint)
                canvas.restore()
            }

            // Darkened badge fill color: Color.lerp(eventColor, Color.BLACK, 0.36f)
            val badgeColor = darkenColor(eventColor, 0.36f)
            val capPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = badgeColor
                style = Paint.Style.FILL
            }
            canvas.drawPath(capPath, capPaint)

            // Timestamp text (e.g. 9:00 AM, 12:00 PM, 3:30 PM)
            val cal = Calendar.getInstance().apply { timeInMillis = timeMs }
            val timeFormat = if (is24HourMode) {
                SimpleDateFormat("HH:mm", Locale.US)
            } else {
                SimpleDateFormat("h:mm a", Locale.US)
            }
            val timeStr = timeFormat.format(cal.time)

            val midAngleDeg = startDeg + (sweepDeg / 2f)
            val midRad = Math.toRadians((midAngleDeg - 90.0).toDouble())
            val midR = (rIn + rOut) / 2f
            val textCenterX = centerX + midR * Math.cos(midRad).toFloat()
            val textCenterY = centerY + midR * Math.sin(midRad).toFloat()

            val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = (if (is24HourMode) 8.6f else 9.6f) * scale
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }

            canvas.save()
            canvas.clipPath(capPath)
            canvas.translate(textCenterX, textCenterY)

            var rotation = midRad
            if (Math.cos(midRad) < -0.05) {
                rotation += Math.PI
            }
            canvas.rotate(Math.toDegrees(rotation).toFloat())

            val textY = -((textPaint.descent() + textPaint.ascent()) / 2f)
            canvas.drawText(timeStr, 0f, textY, textPaint)
            canvas.restore()
        }

        private fun drawRiverPebbles(
            canvas: Canvas,
            centerX: Float,
            centerY: Float,
            rIn: Float,
            rOut: Float,
            startDeg: Float,
            sweepDeg: Float,
            subtasks: List<String>,
            centerTitleHalfDeg: Float,
            startCapSpan: Float,
            endCapSpan: Float,
            textColor: Int,
            scale: Float,
            kalamTypeface: Typeface,
            isDarkSector: Boolean
        ) {
            if (subtasks.isEmpty() || sweepDeg < 20f) return

            val rawPebbles = subtasks.take(4).map { distillShortKeyword(it) }.filter { it.isNotEmpty() }
            if (rawPebbles.isEmpty()) return

            val effectiveStart = startDeg + startCapSpan
            val effectiveEnd = (startDeg + sweepDeg) - endCapSpan
            val effectiveSweep = maxOf(1f, effectiveEnd - effectiveStart)
            val effectiveMidDeg = effectiveStart + effectiveSweep / 2f
            val midR = (rIn + rOut) / 2f

            val pebbleFontSize = 10.5f * scale
            val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textColor
                textSize = pebbleFontSize
                typeface = Typeface.create(kalamTypeface, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }

            val pebbleBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (isDarkSector) Color.argb(76, Color.red(textColor), Color.green(textColor), Color.blue(textColor))
                        else Color.argb(56, Color.red(textColor), Color.green(textColor), Color.blue(textColor))
                style = Paint.Style.FILL
            }
            val pebbleBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (isDarkSector) Color.argb(165, Color.red(textColor), Color.green(textColor), Color.blue(textColor))
                        else Color.argb(115, Color.red(textColor), Color.green(textColor), Color.blue(textColor))
                style = Paint.Style.STROKE
                strokeWidth = 1.3f * scale
            }

            data class PebbleDim(val text: String, val w: Float, val h: Float, val halfDeg: Float)

            val pebbleDims = rawPebbles.map { text ->
                val tw = textPaint.measureText(text)
                val th = textPaint.descent() - textPaint.ascent()
                val w = tw + 7f * scale
                val h = th + 4.5f * scale
                val halfDeg = (w / 2f) / (midR * Math.PI.toFloat() / 180f)
                PebbleDim(text, w, h, halfDeg)
            }

            val leftBayStart = effectiveStart + 8.5f
            val leftBayEnd = effectiveMidDeg - centerTitleHalfDeg - 4.0f
            val leftBayWidth = leftBayEnd - leftBayStart

            val rightBayStart = effectiveMidDeg + centerTitleHalfDeg + 4.0f
            val rightBayEnd = effectiveEnd - 8.5f
            val rightBayWidth = rightBayEnd - rightBayStart

            val tilts = if (sweepDeg < 45f) floatArrayOf(0f, 0f, 0f, 0f) else floatArrayOf(-0.04f, 0.05f, -0.05f, 0.04f)

            fun renderPebble(dim: PebbleDim, angleDeg: Float, tilt: Float, radiusOffset: Float = 0f, scaleFactor: Float = 1.0f) {
                val rad = Math.toRadians((angleDeg - 90.0).toDouble())
                val pr = midR + radiusOffset
                val px = centerX + pr * Math.cos(rad).toFloat()
                val py = centerY + pr * Math.sin(rad).toFloat()

                canvas.save()
                canvas.translate(px, py)
                var tangentRad = rad + Math.PI / 2.0
                if (Math.cos(tangentRad) < 0.05) {
                    tangentRad += Math.PI
                }
                tangentRad += tilt
                canvas.rotate(Math.toDegrees(tangentRad).toFloat())

                val rw = (dim.w * scaleFactor) / 2f
                val rh = (dim.h * scaleFactor) / 2f
                val rect = RectF(-rw, -rh, rw, rh)
                val cornerRadius = rh
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, pebbleBgPaint)
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, pebbleBorderPaint)

                val oldSize = textPaint.textSize
                textPaint.textSize = oldSize * scaleFactor
                val textY = -((textPaint.descent() + textPaint.ascent()) / 2f)
                canvas.drawText(dim.text, 0f, textY, textPaint)
                textPaint.textSize = oldSize
                canvas.restore()
            }

            val trackThickness = rOut - rIn
            val radialDelta = minOf(12f * scale, trackThickness * 0.22f)

            fun renderBayPebbleSingle(dim: PebbleDim, bayStart: Float, bayEnd: Float, bayW: Float, tilt: Float) {
                if (bayW <= 0f) return
                val maxAllowedW = maxOf(0f, bayW - 1.2f)
                val scaleFactor = (maxAllowedW / (dim.halfDeg * 2f)).coerceIn(0.75f, 1.0f)
                val scaledHalf = dim.halfDeg * scaleFactor
                val minSafe = bayStart + scaledHalf
                val maxSafe = bayEnd - scaledHalf
                val targetAngle = if (minSafe <= maxSafe) ((bayStart + bayEnd) / 2f).coerceIn(minSafe, maxSafe) else ((bayStart + bayEnd) / 2f)
                renderPebble(dim, targetAngle, tilt, radiusOffset = 0f, scaleFactor = scaleFactor)
            }

            fun renderBayPebblesTwo(dim1: PebbleDim, dim2: PebbleDim, bayStart: Float, bayEnd: Float, bayW: Float, t1: Float, t2: Float) {
                if (bayW <= 0f) return
                val fullW1 = dim1.halfDeg * 2f
                val fullW2 = dim2.halfDeg * 2f
                val required = fullW1 + 3.0f + fullW2
                if (bayW < required) {
                    // Radial staggering across track thickness:
                    val maxAllowedW = maxOf(0f, bayW - 1.2f)
                    val sScale1 = (maxAllowedW / fullW1).coerceIn(0.72f, 1.0f)
                    val sScale2 = (maxAllowedW / fullW2).coerceIn(0.72f, 1.0f)
                    val sHalf1 = dim1.halfDeg * sScale1
                    val sHalf2 = dim2.halfDeg * sScale2

                    val bayMid = (bayStart + bayEnd) / 2f
                    val angSep = (bayW * 0.12f).coerceIn(0.8f, 2.0f)

                    val minSafe1 = bayStart + sHalf1
                    val maxSafe1 = bayEnd - sHalf1
                    val p1Angle = if (minSafe1 <= maxSafe1) (bayMid - angSep).coerceIn(minSafe1, maxSafe1) else bayMid

                    val minSafe2 = bayStart + sHalf2
                    val maxSafe2 = bayEnd - sHalf2
                    val p2Angle = if (minSafe2 <= maxSafe2) (bayMid + angSep).coerceIn(minSafe2, maxSafe2) else bayMid

                    renderPebble(dim1, p1Angle, 0f, radiusOffset = radialDelta, scaleFactor = sScale1)
                    renderPebble(dim2, p2Angle, 0f, radiusOffset = -radialDelta, scaleFactor = sScale2)
                } else {
                    val scaleFactor = (bayW / required).coerceIn(0.70f, 1.0f)
                    val sHalf1 = dim1.halfDeg * scaleFactor
                    val sHalf2 = dim2.halfDeg * scaleFactor
                    val betweenGap = 3.0f * scaleFactor
                    val p1Angle = (bayStart + 1.0f + sHalf1).coerceIn(bayStart + sHalf1, bayEnd - sHalf1)
                    val p2Angle = (p1Angle + sHalf1 + betweenGap + sHalf2).coerceIn(bayStart + sHalf2, bayEnd - sHalf2)
                    renderPebble(dim1, p1Angle, t1, scaleFactor = scaleFactor)
                    renderPebble(dim2, p2Angle, t2, scaleFactor = scaleFactor)
                }
            }

            if (pebbleDims.size == 1) {
                val p = pebbleDims[0]
                if (leftBayWidth >= rightBayWidth) {
                    renderBayPebbleSingle(p, leftBayStart, leftBayEnd, leftBayWidth, tilts[0])
                } else {
                    renderBayPebbleSingle(p, rightBayStart, rightBayEnd, rightBayWidth, tilts[0])
                }
            } else if (pebbleDims.size == 2) {
                val p1 = pebbleDims[0]
                val p2 = pebbleDims[1]

                if (leftBayWidth >= p1.halfDeg * 1.5f && rightBayWidth >= p2.halfDeg * 1.5f) {
                    renderBayPebbleSingle(p1, leftBayStart, leftBayEnd, leftBayWidth, tilts[0])
                    renderBayPebbleSingle(p2, rightBayStart, rightBayEnd, rightBayWidth, tilts[1])
                } else if (leftBayWidth >= rightBayWidth) {
                    renderBayPebblesTwo(p1, p2, leftBayStart, leftBayEnd, leftBayWidth, tilts[0], tilts[1])
                } else {
                    renderBayPebblesTwo(p1, p2, rightBayStart, rightBayEnd, rightBayWidth, tilts[0], tilts[1])
                }
            } else if (pebbleDims.size >= 3) {
                val p1 = pebbleDims[0]
                val p2 = pebbleDims[1]
                val p3 = pebbleDims[2]

                // Allocate 2 pebbles to wider bay and 1 to other bay with strict boundary clamping
                if (leftBayWidth >= rightBayWidth) {
                    renderBayPebblesTwo(p1, p2, leftBayStart, leftBayEnd, leftBayWidth, tilts[0], tilts[1])
                    renderBayPebbleSingle(p3, rightBayStart, rightBayEnd, rightBayWidth, tilts[2])
                } else {
                    renderBayPebbleSingle(p1, leftBayStart, leftBayEnd, leftBayWidth, tilts[0])
                    renderBayPebblesTwo(p2, p3, rightBayStart, rightBayEnd, rightBayWidth, tilts[1], tilts[2])
                }
            }
        }

        private fun drawDynamicSectors(
            context: Context,
            canvas: Canvas,
            centerX: Float,
            centerY: Float,
            baseRadius: Float,
            innerRadius: Float,
            scale: Float,
            nowMs: Long,
            is24HourMode: Boolean,
            dialBgColor: Int,
            prefs: SharedPreferences,
            dynamicFocusAngle: Float,
            dynamicMagnification: Float,
            isLensEnabled: Boolean
        ) {
            val kalamTypeface = getKalamTypeface(context)

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
                val rawDeg = h * stepDeg
                val visualDeg = if (isLensEnabled && dynamicFocusAngle >= 0f && dynamicMagnification > 1.001f) {
                    warpAngle(rawDeg.toDouble(), dynamicFocusAngle.toDouble(), dynamicMagnification.toDouble()).toFloat()
                } else rawDeg
                val rad = Math.toRadians((visualDeg - 90f).toDouble())
                val x1 = centerX + innerRadius * Math.cos(rad).toFloat()
                val y1 = centerY + innerRadius * Math.sin(rad).toFloat()
                val x2 = centerX + (baseRadius - 8f * scale) * Math.cos(rad).toFloat()
                val y2 = centerY + (baseRadius - 8f * scale) * Math.sin(rad).toFloat()
                canvas.drawLine(x1, y1, x2, y2, spokePaint)
            }

            // 2. Parse and Filter Events from eventsJson
            val eventsJsonStr = prefs.getString(KEY_EVENTS_JSON, null)
            val allEvents = mutableListOf<NativeSectorEvent>()
            val todayCal = Calendar.getInstance().apply { timeInMillis = nowMs }
            val tYear = todayCal.get(Calendar.YEAR)
            val tMonth = todayCal.get(Calendar.MONTH)
            val tDay = todayCal.get(Calendar.DAY_OF_MONTH)

            if (!eventsJsonStr.isNullOrEmpty()) {
                try {
                    val arr = JSONArray(eventsJsonStr)
                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        val id = obj.optString("id", i.toString())
                        val title = obj.optString("title", "")
                        val rawStart = obj.optLong("start", 0L)
                        val rawEnd = obj.optLong("end", 0L)
                        val colorVal = obj.optLong("color", -1L)
                        val color = if (colorVal != -1L) colorVal.toInt() else Color.parseColor("#38BDF8")
                        val iconName = if (obj.has("iconName") && !obj.isNull("iconName")) obj.optString("iconName") else null
                        val subtasks = mutableListOf<String>()
                        val subtasksArr = obj.optJSONArray("subtasks")
                        if (subtasksArr != null) {
                            for (s in 0 until subtasksArr.length()) {
                                val st = subtasksArr.optString(s)
                                if (st.isNotEmpty()) subtasks.add(st)
                            }
                        }
                        if (rawEnd > rawStart && title.isNotEmpty()) {
                            val evCal = Calendar.getInstance().apply { timeInMillis = rawStart }
                            val sHour = evCal.get(Calendar.HOUR_OF_DAY)
                            val sMin = evCal.get(Calendar.MINUTE)
                            val durMs = rawEnd - rawStart

                            val pCal = Calendar.getInstance().apply {
                                set(Calendar.YEAR, tYear)
                                set(Calendar.MONTH, tMonth)
                                set(Calendar.DAY_OF_MONTH, tDay)
                                set(Calendar.HOUR_OF_DAY, sHour)
                                set(Calendar.MINUTE, sMin)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }
                            val start = pCal.timeInMillis
                            val end = start + durMs

                            allEvents.add(NativeSectorEvent(id, title, start, end, color, subtasks, iconName))
                        }
                    }
                } catch (_: Exception) {}
            }

            // 3. Rolling Horizon Selection (1 past block, 1 active block, upcoming blocks within 12 hours)
            val horizonEvents = mutableListOf<NativeSectorEvent>()
            val activeEvent = allEvents.firstOrNull { nowMs in it.start until it.end }
            val pastEvents = allEvents.filter { it.end <= nowMs && (nowMs - it.end) <= 4 * 3600 * 1000L }
                .sortedByDescending { it.end }
            val upcomingEvents = allEvents.filter { it.start >= nowMs && (it.start - nowMs) <= 12 * 3600 * 1000L }
                .sortedBy { it.start }

            val pastBlocksCount = prefs.getInt(KEY_PREVIOUS_BLOCKS_COUNT, 1)
            val futureBlocksCount = prefs.getInt(KEY_FUTURE_BLOCKS_COUNT, 3)

            for (past in pastEvents.take(pastBlocksCount)) {
                if (!horizonEvents.any { h -> h.id == past.id }) {
                    horizonEvents.add(past)
                }
            }
            activeEvent?.let { if (!horizonEvents.any { h -> h.id == it.id }) horizonEvents.add(it) }
            for (up in upcomingEvents.take(futureBlocksCount)) {
                if (!horizonEvents.any { h -> h.id == up.id }) {
                    horizonEvents.add(up)
                }
            }

            // Sort by start time for consistent clockwise layout
            horizonEvents.sortBy { it.start }

            val rIn = innerRadius + 2f * scale
            val rOut = baseRadius - 6f * scale
            val rate = if (is24HourMode) 0.25f else 0.5f

            val overlapDeg = if (is24HourMode) 0.8f else 1.2f

            data class SectorLayout(
                val event: NativeSectorEvent,
                val startDeg: Float,
                val sweepDeg: Float,
                val pillPath: Path,
                val showStartCap: Boolean,
                val startCapSpan: Float,
                val effectiveStartCap: Float,
                val showEndCap: Boolean,
                val endCapStartDeg: Float,
                val endCapSpan: Float,
                val isContiguousWithNext: Boolean,
                val isContiguousWithPrev: Boolean
            )

            data class EventGeom(var startDeg: Float, var sweepDeg: Float)

            val geoms = horizonEvents.map { ev ->
                val cal = Calendar.getInstance().apply { timeInMillis = ev.start }
                val h = if (is24HourMode) cal.get(Calendar.HOUR_OF_DAY) else (cal.get(Calendar.HOUR) % 12)
                val m = cal.get(Calendar.MINUTE)
                val s = cal.get(Calendar.SECOND)
                val rawStart = ((h * 60 + m + s / 60f) * rate) % 360f
                val durMin = (ev.end - ev.start) / (60f * 1000f)
                val rawSweep = (durMin * rate).coerceIn(4f, 360f)
                EventGeom(rawStart, rawSweep)
            }.toMutableList()

            // Contiguous Monolithic Rebalancing:
            // Borrow space backward/forward from contiguous blocks with no subtasks (e.g. Sleep with large sweep)
            val minMonolithic = if (is24HourMode) 28f else 45f
            for (i in 0 until horizonEvents.size) {
                val ev = horizonEvents[i]
                if (ev.subtasks.isEmpty()) continue

                val targetFloor = when (ev.subtasks.size) {
                    1 -> if (is24HourMode) 40f else 70f
                    2 -> if (is24HourMode) 50f else 88f
                    3 -> if (is24HourMode) 62f else 110f
                    else -> if (is24HourMode) (62f + (ev.subtasks.size - 3) * 6f).coerceAtMost(80f)
                            else (110f + (ev.subtasks.size - 3) * 10f).coerceAtMost(130f)
                }
                var deficit = targetFloor - geoms[i].sweepDeg
                if (deficit <= 0.001f) continue

                val prevIdx = if (i > 0) i - 1 else horizonEvents.size - 1
                val prevEv = horizonEvents[prevIdx]
                val isPrevContiguous = Math.abs(ev.start - prevEv.end) <= 60000L || Math.abs((ev.start - prevEv.end) % 86400000L) <= 60000L
                if (isPrevContiguous && prevEv.subtasks.isEmpty()) {
                    var minDonor = minMonolithic
                    if (nowMs in prevEv.start until prevEv.end) {
                        val elapsedMin = (nowMs - prevEv.start) / 60000f
                        val needleOffsetDeg = elapsedMin * rate
                        minDonor = maxOf(minDonor, needleOffsetDeg + 12f)
                    }
                    val prevAvail = maxOf(0f, geoms[prevIdx].sweepDeg - minDonor)
                    if (prevAvail > 0f) {
                        val take = minOf(deficit, prevAvail)
                        geoms[prevIdx].sweepDeg -= take
                        geoms[i].startDeg = (geoms[i].startDeg - take + 360f) % 360f
                        geoms[i].sweepDeg += take
                        deficit -= take
                    }
                }

                if (deficit > 0.001f) {
                    val nextIdx = (i + 1) % horizonEvents.size
                    val nextEv = horizonEvents[nextIdx]
                    val isNextContiguous = Math.abs(nextEv.start - ev.end) <= 60000L || Math.abs((nextEv.start - ev.end) % 86400000L) <= 60000L
                    if (isNextContiguous && nextEv.subtasks.isEmpty()) {
                        var minDonor = minMonolithic
                        if (nowMs in nextEv.start until nextEv.end) {
                            val remMin = (nextEv.end - nowMs) / 60000f
                            val needleFromEndDeg = remMin * rate
                            minDonor = maxOf(minDonor, needleFromEndDeg + 12f)
                        }
                        val nextAvail = maxOf(0f, geoms[nextIdx].sweepDeg - minDonor)
                        if (nextAvail > 0f) {
                            val takeFwd = minOf(deficit, nextAvail)
                            geoms[i].sweepDeg += takeFwd
                            geoms[nextIdx].startDeg = (geoms[nextIdx].startDeg + takeFwd) % 360f
                            geoms[nextIdx].sweepDeg -= takeFwd
                            deficit -= takeFwd
                        }
                    }
                }
            }

            val layouts = mutableListOf<SectorLayout>()

            for (i in 0 until horizonEvents.size) {
                val event = horizonEvents[i]
                val rawStartDeg = geoms[i].startDeg
                val isEventActive = (nowMs in event.start until event.end)
                val unwarpedSweep = if (isEventActive) {
                    maxOf(geoms[i].sweepDeg, 36f)
                } else {
                    geoms[i].sweepDeg
                }

                // Warp start and end angles using FisheyeTimeLens for 100% in-app parity
                val dialDeg: Float
                val sweepDeg: Float
                if (isLensEnabled && dynamicFocusAngle >= 0f && dynamicMagnification > 1.001f) {
                    val wStart = warpAngle(rawStartDeg.toDouble(), dynamicFocusAngle.toDouble(), dynamicMagnification.toDouble()).toFloat()
                    val wEnd = warpAngle((rawStartDeg + unwarpedSweep).toDouble(), dynamicFocusAngle.toDouble(), dynamicMagnification.toDouble()).toFloat()
                    var wSweep = wEnd - wStart
                    if (wSweep < 0f) wSweep += 360f
                    if (wSweep == 0f && unwarpedSweep > 0f) wSweep = 360f
                    dialDeg = wStart
                    sweepDeg = wSweep
                } else {
                    dialDeg = rawStartDeg
                    sweepDeg = unwarpedSweep
                }

                val prevEvent = if (i > 0) horizonEvents[i - 1] else null
                val nextEvent = if (i < horizonEvents.size - 1) horizonEvents[i + 1] else null

                val isContiguousWithPrev = prevEvent != null && Math.abs(event.start - prevEvent.end) <= 60000L
                val isContiguousWithNext = nextEvent != null && Math.abs(nextEvent.start - event.end) <= 60000L

                val cornerR = minOf(6f * scale, (rOut - rIn) * 0.22f)

                val standardCapSpan = if (is24HourMode) 5.5f else 9.2f
                val baseCapSpan = minOf(standardCapSpan, sweepDeg * 0.35f)

                val showStartCap = !isContiguousWithPrev && sweepDeg >= 14f
                val showEndCap = sweepDeg >= 14f

                val startCapSpan = if (showStartCap) baseCapSpan else 0f
                val endCapSpan = if (showEndCap) baseCapSpan + (if (isContiguousWithNext) overlapDeg else 0f) else 0f
                val endBoundaryDeg = dialDeg + sweepDeg
                val capEndDeg = endBoundaryDeg + (if (isContiguousWithNext) overlapDeg else 0f)
                val endCapStartDeg = capEndDeg - endCapSpan
                val effectiveStartCap = if (showStartCap) startCapSpan else (if (isContiguousWithPrev) overlapDeg else 0f)

                val pillPath = buildPillPath(
                    centerX, centerY, rIn, rOut,
                    dialDeg, sweepDeg,
                    cornerRadius = cornerR,
                    roundStart = !isContiguousWithPrev,
                    roundEnd = !isContiguousWithNext
                )

                layouts.add(
                    SectorLayout(
                        event = event,
                        startDeg = dialDeg,
                        sweepDeg = sweepDeg,
                        pillPath = pillPath,
                        showStartCap = showStartCap,
                        startCapSpan = startCapSpan,
                        effectiveStartCap = effectiveStartCap,
                        showEndCap = showEndCap,
                        endCapStartDeg = endCapStartDeg,
                        endCapSpan = endCapSpan,
                        isContiguousWithNext = isContiguousWithNext,
                        isContiguousWithPrev = isContiguousWithPrev
                    )
                )
            }

            // PASS 1: Sector Pill Bodies
            for (l in layouts) {
                val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = l.event.color
                    style = Paint.Style.FILL
                }
                canvas.drawPath(l.pillPath, fillPaint)
            }

            val materialIconsTypeface = getMaterialIconsTypeface(context)

            // PASS 2: Sector Content (Monochrome Icon, Kalam Title, Duration & River Pebble Subtasks)
            for (l in layouts) {
                if (l.sweepDeg < 10f) continue

                val effStart = l.startDeg + l.effectiveStartCap
                val effEnd = (l.startDeg + l.sweepDeg) - l.endCapSpan
                val effSweep = maxOf(1f, effEnd - effStart)
                val midDeg = effStart + effSweep / 2f
                val midRad = Math.toRadians((midDeg - 90.0).toDouble())
                val midR = (rIn + rOut) / 2f
                val posX = centerX + midR * Math.cos(midRad).toFloat()
                val posY = centerY + midR * Math.sin(midRad).toFloat()

                val lum = (0.299 * Color.red(l.event.color) + 0.587 * Color.green(l.event.color) + 0.114 * Color.blue(l.event.color)) / 255.0
                val isDarkSector = lum <= 0.55
                val textColor = if (isDarkSector) Color.parseColor("#F7F3EE") else Color.parseColor("#1E1A16")

                val iconGlyph = getEventIconGlyph(l.event.title, l.event.iconName)
                val keyword = distillShortKeyword(l.event.title)

                val durMin = ((l.event.end - l.event.start) / (60 * 1000L)).toInt()
                val durStr = if (durMin >= 60) {
                    val h = durMin / 60
                    val m = durMin % 60
                    if (m > 0) "${h}h ${m}m" else "${h}h"
                } else {
                    "${durMin}m"
                }

                val iconPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = textColor
                    textSize = 12.0f * scale
                    typeface = materialIconsTypeface
                    textAlign = Paint.Align.CENTER
                }
                val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = textColor
                    textSize = 10.5f * scale
                    typeface = kalamTypeface
                    textAlign = Paint.Align.CENTER
                }
                val durPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (isDarkSector) Color.argb(225, 247, 243, 238) else Color.argb(225, 30, 26, 22)
                    textSize = 8.8f * scale
                    typeface = kalamTypeface
                    textAlign = Paint.Align.CENTER
                }

                val titleW = titlePaint.measureText(keyword)
                val centerTitleHalfDeg = ((titleW + 6f * scale) / 2f) / (midR * Math.PI.toFloat() / 180f)

                canvas.save()
                canvas.translate(posX, posY)
                var tangentRad = midRad + Math.PI / 2.0
                if (Math.cos(tangentRad) < 0.05) {
                    tangentRad += Math.PI
                }
                canvas.rotate(Math.toDegrees(tangentRad).toFloat())

                // 3 Content Tiers (matching SectorContentRenderer):
                // Tier 1: Small sweep (< 20° in 12H, < 12° in 24H) -> Icon only (e.g. Break)
                // Tier 2: Medium sweep (20° to 38°) -> Icon + Title (e.g. Workout)
                // Tier 3: Large sweep (>= 38°) -> Icon + Title + Duration (e.g. Study Time 3h)
                val isSmallSector = l.sweepDeg < (if (is24HourMode) 12f else 20f)
                val isLargeSector = l.sweepDeg >= (if (is24HourMode) 25f else 38f)

                val showIconOnly = isSmallSector
                val showDur = isLargeSector

                val words = l.event.title.trim().split(Regex("""\s+""")).filter { it.isNotEmpty() }
                val displayLines = if (!showIconOnly && words.size == 2 && l.sweepDeg >= 48f) words
                                   else if (!showIconOnly) listOf(keyword)
                                   else emptyList()

                val iconH = 12f * scale
                val titleLineH = if (displayLines.isNotEmpty()) titlePaint.descent() - titlePaint.ascent() else 0f
                val totalTitleH = titleLineH * displayLines.size
                val durH = if (showDur) durPaint.descent() - durPaint.ascent() else 0f

                val totalContentH = iconH + totalTitleH + (if (showDur) durH + 1f * scale else 0f)
                var curY = -totalContentH / 2f

                // 1. Icon (Always drawn; centered in small sectors like Break)
                curY += iconH * 0.8f
                canvas.drawText(iconGlyph, 0f, curY, iconPaint)
                curY += 2f * scale

                // 2. Title lines (for medium and large sectors)
                for (line in displayLines) {
                    curY += titleLineH * 0.85f
                    canvas.drawText(line, 0f, curY, titlePaint)
                }

                // 3. Duration (for large sectors)
                if (showDur) {
                    curY += durH * 0.9f + 1f * scale
                    canvas.drawText(durStr, 0f, curY, durPaint)
                }
                canvas.restore()

                // River Pebble Subtasks in left and right bays
                if (l.event.subtasks.isNotEmpty() && l.sweepDeg >= 20f) {
                    drawRiverPebbles(
                        canvas = canvas,
                        centerX = centerX,
                        centerY = centerY,
                        rIn = rIn,
                        rOut = rOut,
                        startDeg = l.startDeg,
                        sweepDeg = l.sweepDeg,
                        subtasks = l.event.subtasks,
                        centerTitleHalfDeg = centerTitleHalfDeg,
                        startCapSpan = l.effectiveStartCap,
                        endCapSpan = l.endCapSpan,
                        textColor = textColor,
                        scale = scale,
                        kalamTypeface = kalamTypeface,
                        isDarkSector = isDarkSector
                    )
                }
            }

            // PASS 3: Boundary Timestamp Caps (Draw on top of sector bodies)
            for (l in layouts) {
                val cornerR = minOf(6f * scale, (rOut - rIn) * 0.22f)

                // End cap (Draws on top of successor blocks with drop shadow when contiguous!)
                if (l.showEndCap) {
                    drawIntegratedCap(
                        canvas = canvas,
                        centerX = centerX,
                        centerY = centerY,
                        rIn = rIn,
                        rOut = rOut,
                        startDeg = l.endCapStartDeg,
                        sweepDeg = l.endCapSpan,
                        timeMs = l.event.end,
                        eventColor = l.event.color,
                        isStartCap = false,
                        is24HourMode = is24HourMode,
                        scale = scale,
                        cornerRadius = cornerR,
                        roundStart = false,
                        roundEnd = true,
                        isContiguous = l.isContiguousWithNext,
                        overlapDeg = if (l.isContiguousWithNext) overlapDeg else 0f
                    )
                }

                // Start cap
                if (l.showStartCap) {
                    drawIntegratedCap(
                        canvas = canvas,
                        centerX = centerX,
                        centerY = centerY,
                        rIn = rIn,
                        rOut = rOut,
                        startDeg = l.startDeg,
                        sweepDeg = l.startCapSpan,
                        timeMs = l.event.start,
                        eventColor = l.event.color,
                        isStartCap = true,
                        is24HourMode = is24HourMode,
                        scale = scale,
                        cornerRadius = cornerR,
                        roundStart = !l.isContiguousWithPrev,
                        roundEnd = false,
                        isContiguous = false,
                        overlapDeg = 0f
                    )
                }
            }

            // PASS 4: Bezel Outline, 48 Ticks & 3D Numerals
            val outlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#374151")
                style = Paint.Style.STROKE
                strokeWidth = 1.2f * scale
            }
            canvas.drawCircle(centerX, centerY, baseRadius, outlinePaint)

            val tickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(102, 229, 231, 235) // Color(0xFFE5E7EB) alpha 0.40
                strokeWidth = 1.0f * scale
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
            }
            val intervals = 48
            val intervalsPerHour = if (is24HourMode) 2 else 4
            for (i in 0 until intervals) {
                if (i % intervalsPerHour == 0) continue // Skip positions where hour numerals sit
                val rawDeg = (i / intervals.toFloat()) * 360f
                val visualDeg = if (isLensEnabled && dynamicFocusAngle >= 0f && dynamicMagnification > 1.001f) {
                    warpAngle(rawDeg.toDouble(), dynamicFocusAngle.toDouble(), dynamicMagnification.toDouble()).toFloat()
                } else rawDeg
                val deg = visualDeg - 90f
                val rad = Math.toRadians(deg.toDouble())
                val isHalfHour = (!is24HourMode && i % 2 == 0)
                val tickLen = (if (isHalfHour) 3.5f else 2.0f) * scale
                val x1 = centerX + baseRadius * Math.cos(rad).toFloat()
                val y1 = centerY + baseRadius * Math.sin(rad).toFloat()
                val x2 = centerX + (baseRadius - tickLen) * Math.cos(rad).toFloat()
                val y2 = centerY + (baseRadius - tickLen) * Math.sin(rad).toFloat()
                canvas.drawLine(x1, y1, x2, y2, tickPaint)
            }

            // 3D Hour Numbers Centered on trackOuterRadius (rOut)
            // Straddling half over the block and half outside!
            val numRadius = rOut
            val numFontSize = (if (is24HourMode) 8.5f else 11.5f) * scale
            val numTypeface = Typeface.create("sans-serif-black", Typeface.BOLD)

            // 1. Ambient Drop Shadow (blurRadius = 3.5f * scale, dy = 1.8f * scale)
            val numShadowPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(240, 0, 0, 0)
                textSize = numFontSize
                typeface = numTypeface
                textAlign = Paint.Align.CENTER
                maskFilter = BlurMaskFilter(3.5f * scale, BlurMaskFilter.Blur.NORMAL)
            }

            // 2. 3D Dark Bezel Outline / Halo (#0F172A, strokeWidth = 2.4f * scale)
            val numHaloPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(235, 15, 23, 42)
                textSize = numFontSize
                typeface = numTypeface
                textAlign = Paint.Align.CENTER
                style = Paint.Style.STROKE
                strokeWidth = 2.4f * scale
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }

            // 3. Crisp Face Fill (#F8FAFC)
            val numFacePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#F8FAFC")
                textSize = numFontSize
                typeface = numTypeface
                textAlign = Paint.Align.CENTER
                style = Paint.Style.FILL
            }

            val hourCount = if (is24HourMode) 24 else 12
            val stepHours = if (is24HourMode) 2 else 1
            for (h in 0 until hourCount step stepHours) {
                val numStr = if (is24HourMode) h.toString() else (if (h == 0) "12" else h.toString())
                val rawDeg = (h / hourCount.toFloat()) * 360f
                val visualDeg = if (isLensEnabled && dynamicFocusAngle >= 0f && dynamicMagnification > 1.001f) {
                    warpAngle(rawDeg.toDouble(), dynamicFocusAngle.toDouble(), dynamicMagnification.toDouble()).toFloat()
                } else rawDeg
                val deg = visualDeg - 90f
                val rad = Math.toRadians(deg.toDouble())
                val nx = centerX + numRadius * Math.cos(rad).toFloat()
                val ny = centerY + numRadius * Math.sin(rad).toFloat()
                val baselineY = ny - ((numFacePaint.descent() + numFacePaint.ascent()) / 2f)

                // 1. Ambient Drop Shadow (dy = 1.8f * scale)
                canvas.drawText(numStr, nx, baselineY + 1.8f * scale, numShadowPaint)
                // 2. 3D Dark Bezel Outline / Halo
                canvas.drawText(numStr, nx, baselineY, numHaloPaint)
                // 3. Crisp Face Fill
                canvas.drawText(numStr, nx, baselineY, numFacePaint)
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
