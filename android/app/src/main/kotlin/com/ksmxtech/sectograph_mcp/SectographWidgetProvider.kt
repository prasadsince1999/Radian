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
                drawDynamicSectors(context, canvas, centerX, centerY, baseRadius, innerRadius, scale, nowMs, is24HourMode, dialBgColor, prefs)
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

        private fun getEventIconGlyph(title: String): String {
            val lower = title.lowercase(Locale.getDefault())
            val codePoint = when {
                lower.contains("cook") || lower.contains("dinner") || lower.contains("lunch") ||
                lower.contains("eat") || lower.contains("meal") || lower.contains("breakfast") ||
                lower.contains("food") -> 0xf0108 // Icons.restaurant_rounded
                lower.contains("code") || lower.contains("work") || lower.contains("study") ||
                lower.contains("focus") || lower.contains("dev") || lower.contains("project") ||
                lower.contains("laptop") -> 0xf841 // Icons.laptop_mac_rounded
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
                val shadowClip = buildPillPath(
                    centerX, centerY, rIn - 8f * scale, rOut + 8f * scale,
                    boundaryDeg, 45f,
                    cornerRadius = 0f,
                    roundStart = false,
                    roundEnd = false
                )
                canvas.clipPath(shadowClip)
                val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.argb(100, 0, 0, 0)
                    maskFilter = BlurMaskFilter(2.8f * scale, BlurMaskFilter.Blur.NORMAL)
                }
                canvas.drawPath(capPath, shadowPaint)
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
            if (subtasks.isEmpty() || sweepDeg < 26f) return

            val rawPebbles = subtasks.take(4).map { distillShortKeyword(it) }.filter { it.isNotEmpty() }
            if (rawPebbles.isEmpty()) return

            val midDeg = startDeg + sweepDeg / 2f
            val midR = (rIn + rOut) / 2f

            val pebbleFontSize = 9.2f * scale
            val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textColor
                textSize = pebbleFontSize
                typeface = kalamTypeface
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
                val w = tw + 9f * scale
                val h = th + 5f * scale
                val halfDeg = (w / 2f) / (midR * Math.PI.toFloat() / 180f)
                PebbleDim(text, w, h, halfDeg)
            }

            val leftBayStart = startDeg + startCapSpan + 1.5f
            val leftBayEnd = midDeg - centerTitleHalfDeg - 1.5f
            val leftBayWidth = leftBayEnd - leftBayStart

            val rightBayStart = midDeg + centerTitleHalfDeg + 1.5f
            val rightBayEnd = (startDeg + sweepDeg) - endCapSpan - 1.5f
            val rightBayWidth = rightBayEnd - rightBayStart

            val tilts = floatArrayOf(-0.04f, 0.05f, -0.05f, 0.04f)

            fun renderPebble(dim: PebbleDim, angleDeg: Float, tilt: Float) {
                val rad = Math.toRadians((angleDeg - 90.0).toDouble())
                val px = centerX + midR * Math.cos(rad).toFloat()
                val py = centerY + midR * Math.sin(rad).toFloat()

                canvas.save()
                canvas.translate(px, py)
                var tangentRad = rad + Math.PI / 2.0
                if (Math.cos(tangentRad) < 0.05) {
                    tangentRad += Math.PI
                }
                tangentRad += tilt
                canvas.rotate(Math.toDegrees(tangentRad).toFloat())

                val rect = RectF(-dim.w / 2f, -dim.h / 2f, dim.w / 2f, dim.h / 2f)
                val cornerRadius = dim.h / 2f
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, pebbleBgPaint)
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, pebbleBorderPaint)

                val textY = -((textPaint.descent() + textPaint.ascent()) / 2f)
                canvas.drawText(dim.text, 0f, textY, textPaint)
                canvas.restore()
            }

            if (pebbleDims.size == 1) {
                val p = pebbleDims[0]
                if (leftBayWidth >= p.halfDeg * 2f + 1f) {
                    renderPebble(p, (leftBayStart + leftBayEnd) / 2f, tilts[0])
                } else if (rightBayWidth >= p.halfDeg * 2f + 1f) {
                    renderPebble(p, (rightBayStart + rightBayEnd) / 2f, tilts[0])
                }
            } else if (pebbleDims.size >= 2) {
                val p1 = pebbleDims[0]
                val p2 = pebbleDims[1]

                if (leftBayWidth >= p1.halfDeg * 1.5f) {
                    renderPebble(p1, (leftBayStart + leftBayEnd) / 2f, tilts[0])
                }
                if (rightBayWidth >= p2.halfDeg * 1.5f) {
                    renderPebble(p2, (rightBayStart + rightBayEnd) / 2f, tilts[1])
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
            prefs: SharedPreferences
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
            val pastEvents = allEvents.filter { it.end <= nowMs && (nowMs - it.end) <= 4 * 3600 * 1000L }
                .sortedByDescending { it.end }
            val upcomingEvents = allEvents.filter { it.start >= nowMs && (it.start - nowMs) <= 12 * 3600 * 1000L }
                .sortedBy { it.start }

            pastEvents.firstOrNull()?.let { horizonEvents.add(it) }
            activeEvent?.let { if (!horizonEvents.any { h -> h.id == it.id }) horizonEvents.add(it) }
            for (up in upcomingEvents.take(3)) {
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

            val layouts = mutableListOf<SectorLayout>()

            for (i in 0 until horizonEvents.size) {
                val event = horizonEvents[i]
                val cal = Calendar.getInstance().apply { timeInMillis = event.start }
                val h = if (is24HourMode) cal.get(Calendar.HOUR_OF_DAY) else (cal.get(Calendar.HOUR) % 12)
                val m = cal.get(Calendar.MINUTE)
                val s = cal.get(Calendar.SECOND)
                val dialDeg = ((h * 60 + m + s / 60f) * rate) % 360f

                val durMin = (event.end - event.start) / (60f * 1000f)
                val sweepDeg = (durMin * rate).coerceIn(4f, 360f)

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

                val midDeg = l.startDeg + l.sweepDeg / 2f
                val midRad = Math.toRadians((midDeg - 90.0).toDouble())
                val midR = (rIn + rOut) / 2f
                val posX = centerX + midR * Math.cos(midRad).toFloat()
                val posY = centerY + midR * Math.sin(midRad).toFloat()

                val lum = (0.299 * Color.red(l.event.color) + 0.587 * Color.green(l.event.color) + 0.114 * Color.blue(l.event.color)) / 255.0
                val isDarkSector = lum <= 0.55
                val textColor = if (isDarkSector) Color.parseColor("#F7F3EE") else Color.parseColor("#1E1A16")

                val iconGlyph = getEventIconGlyph(l.event.title)
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
                if (l.event.subtasks.isNotEmpty() && l.sweepDeg >= 26f) {
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
                val deg = (i / intervals.toFloat()) * 360f - 90f
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
                val deg = (h / hourCount.toFloat()) * 360f - 90f
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
