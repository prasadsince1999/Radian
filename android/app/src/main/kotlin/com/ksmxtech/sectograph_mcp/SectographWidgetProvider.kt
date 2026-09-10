package com.ksmxtech.sectograph_mcp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

class SectographWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_MINUTE_TICK,
            Intent.ACTION_TIME_TICK,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                updateAll(context)
                scheduleNextMinuteAlarm(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextMinuteAlarm(context)
    }

    companion object {
        const val PREFS_NAME = "sectograph_widget_prefs"
        const val KEY_TITLE = "title"
        const val KEY_TIME = "time"
        const val KEY_STATUS = "status"
        const val KEY_DATE = "date"
        const val ACTION_ADD_BLOCK = "com.ksmxtech.sectograph_mcp.ACTION_ADD_BLOCK"
        const val ACTION_MINUTE_TICK = "com.ksmxtech.sectograph_mcp.ACTION_MINUTE_TICK"

        fun scheduleNextMinuteAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager ?: return
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
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC, nextMinute, pendingIntent)
                } else {
                    alarmManager.setExact(android.app.AlarmManager.RTC, nextMinute, pendingIntent)
                }
            } catch (_: Exception) {}
        }

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SectographWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.sectograph_widget)

            // Load high-resolution circular dial bitmap rendered by DialImageRenderer
            val dialFile = File(context.filesDir, "widget_dial.png")
            if (dialFile.exists() && dialFile.canRead()) {
                try {
                    val decodeOptions = BitmapFactory.Options().apply {
                        inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
                        inScaled = false
                    }
                    val bitmap = BitmapFactory.decodeFile(dialFile.absolutePath, decodeOptions)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_dial_image, bitmap)
                    }
                } catch (_: Exception) {}
            }

            // Tap anywhere on the circular dial widget -> Open App
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
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
    }
}
