package com.ksmxtech.sectograph_mcp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build

class NotificationAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "sectograph_event_reminders"
        const val CHANNEL_NAME = "Event & Routine Reminders"
        const val CHANNEL_DESCRIPTION = "Alerts and alarms for upcoming scheduled events and routines"

        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_EVENT_ID = "extra_event_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_COLOR_HEX = "extra_color_hex"
        const val EXTRA_MINUTES_BEFORE = "extra_minutes_before"

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
                val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (existing == null) {
                    val channel = NotificationChannel(
                        CHANNEL_ID,
                        CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = CHANNEL_DESCRIPTION
                        enableLights(true)
                        lightColor = Color.parseColor("#10B981")
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 250, 200, 250)
                        setShowBadge(true)
                        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    }
                    notificationManager.createNotificationChannel(channel)
                }
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, (System.currentTimeMillis() % 100000).toInt())
        val eventId = intent.getStringExtra(EXTRA_EVENT_ID) ?: ""
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Upcoming Event"
        val body = intent.getStringExtra(EXTRA_BODY) ?: "Time for your scheduled block."
        val colorHex = intent.getStringExtra(EXTRA_COLOR_HEX)
        val minutesBefore = intent.getIntExtra(EXTRA_MINUTES_BEFORE, -1)

        createNotificationChannel(context)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        // Intent to launch MainActivity and focus the event
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.ksmxtech.sectograph_mcp.ACTION_OPEN_EVENT"
            putExtra("eventId", eventId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val headline = when {
            minutesBefore == 0 -> "$title starting now"
            minutesBefore > 0 -> "$title in $minutesBefore min"
            else -> title
        }

        val parsedColor = try {
            if (!colorHex.isNullOrEmpty()) Color.parseColor(colorHex) else Color.parseColor("#10B981")
        } catch (_: Exception) {
            Color.parseColor("#10B981")
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder.setContentTitle(headline)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(parsedColor)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_ALL)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setCategory(Notification.CATEGORY_REMINDER)
            builder.setVisibility(Notification.VISIBILITY_PUBLIC)
        }

        notificationManager.notify(notificationId, builder.build())

        // Clean up from SharedPreferences if this was a one-time reminder
        try {
            val prefs = context.getSharedPreferences("sectograph_reminders_prefs", Context.MODE_PRIVATE)
            prefs.edit().remove(eventId).apply()
        } catch (_: Exception) {}
    }
}
