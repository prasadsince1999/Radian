package com.ksmxtech.sectograph_mcp

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            rescheduleAll(context)
        }
    }

    companion object {
        fun rescheduleAll(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val prefs = context.getSharedPreferences("sectograph_reminders_prefs", Context.MODE_PRIVATE)
            val allEntries = prefs.all
            val now = System.currentTimeMillis()

            val editor = prefs.edit()
            for ((key, value) in allEntries) {
                if (value is String) {
                    try {
                        val json = JSONObject(value)
                        val triggerEpochMs = json.getLong("triggerEpochMs")
                        if (triggerEpochMs > now) {
                            val notificationId = json.getInt("notificationId")
                            val eventId = json.getString("eventId")
                            val title = json.getString("title")
                            val body = json.getString("body")
                            val colorHex = json.optString("colorHex", "#10B981")
                            val minutesBefore = json.optInt("minutesBefore", 0)

                            val alarmIntent = Intent(context, NotificationAlarmReceiver::class.java).apply {
                                putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_ID, notificationId)
                                putExtra(NotificationAlarmReceiver.EXTRA_EVENT_ID, eventId)
                                putExtra(NotificationAlarmReceiver.EXTRA_TITLE, title)
                                putExtra(NotificationAlarmReceiver.EXTRA_BODY, body)
                                putExtra(NotificationAlarmReceiver.EXTRA_COLOR_HEX, colorHex)
                                putExtra(NotificationAlarmReceiver.EXTRA_MINUTES_BEFORE, minutesBefore)
                            }

                            val pendingIntent = PendingIntent.getBroadcast(
                                context,
                                notificationId,
                                alarmIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerEpochMs, pendingIntent)
                            } else {
                                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerEpochMs, pendingIntent)
                            }
                        } else {
                            editor.remove(key)
                        }
                    } catch (_: Exception) {
                        editor.remove(key)
                    }
                }
            }
            editor.apply()
        }
    }
}
