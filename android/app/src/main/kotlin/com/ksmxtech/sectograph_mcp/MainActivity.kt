package com.ksmxtech.sectograph_mcp

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Main Android activity coordinating Flutter engine MethodChannels,
 * widget syncing, Health Connect, hardware step tracking, and exact notification alarms.
 */
class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.ksmxtech.sectograph_mcp/widget"
    private val NOTIFICATIONS_CHANNEL = "com.ksmxtech.sectograph_mcp/notifications"

    private var methodChannel: MethodChannel? = null
    private var pendingAction: String? = null

    private lateinit var stepSensorHelper: StepSensorHelper
    private lateinit var widgetSyncHelper: WidgetSyncHelper
    private lateinit var healthConnectHelper: HealthConnectHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stepSensorHelper = StepSensorHelper(this).apply { init() }
        widgetSyncHelper = WidgetSyncHelper(this)
        healthConnectHelper = HealthConnectHelper(this, stepSensorHelper)

        NotificationAlarmReceiver.createNotificationChannel(this)
        handleIntentAction(intent)
    }

    override fun onResume() {
        super.onResume()
        if (::stepSensorHelper.isInitialized) {
            stepSensorHelper.onResume()
        }
    }

    override fun onPause() {
        super.onPause()
        if (::stepSensorHelper.isInitialized) {
            stepSensorHelper.onPause()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentAction(intent)
    }

    private fun handleIntentAction(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("action")
        if (action == "add_block" || intent.action == SectographWidgetProvider.ACTION_ADD_BLOCK) {
            pendingAction = "add_block"
            methodChannel?.invokeMethod("onWidgetAction", "add_block")
        }
        if (intent.action == "com.ksmxtech.sectograph_mcp.ACTION_OPEN_EVENT") {
            val eventId = intent.getStringExtra("eventId")
            if (!eventId.isNullOrEmpty()) {
                methodChannel?.invokeMethod("onOpenEvent", eventId)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Widget & Health MethodChannel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val title = call.argument<String>("title") ?: "Dial is clear"
                        val time = call.argument<String>("time") ?: "Plan your day"
                        val status = call.argument<String>("status") ?: "READY"
                        val date = call.argument<String>("date") ?: ""
                        val dialBytes = call.argument<ByteArray>("dialBytes")
                        result.success(widgetSyncHelper.updateWidget(title, time, status, date, dialBytes))
                    }
                    "getInitialAction" -> {
                        val action = pendingAction
                        pendingAction = null
                        result.success(action)
                    }
                    "pinWidget" -> result.success(widgetSyncHelper.pinWidget())
                    "isBatteryOptimizationIgnored" -> result.success(widgetSyncHelper.isBatteryOptimizationIgnored())
                    "requestIgnoreBatteryOptimization" -> result.success(widgetSyncHelper.requestIgnoreBatteryOptimization(this@MainActivity))
                    "openBatterySettings" -> result.success(widgetSyncHelper.openBatterySettings(this@MainActivity))
                    "isHealthConnectAvailable" -> result.success(healthConnectHelper.isHealthConnectAvailable())
                    "hasHealthPermissions" -> result.success(healthConnectHelper.hasHealthPermissions())
                    "requestHealthPermissions" -> result.success(healthConnectHelper.requestHealthPermissions())
                    "openHealthConnectSettings" -> result.success(healthConnectHelper.openHealthConnectSettings())
                    "getDailyHealthSummary" -> {
                        val dateArg = call.argument<String>("date")
                        healthConnectHelper.fetchDailyHealthSummary(dateArg) { summaryMap ->
                            result.success(summaryMap)
                        }
                    }
                    "areNotificationsEnabled" -> result.success(areNotificationsEnabled())
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    else -> result.notImplemented()
                }
            }
        }

        // 2. Exact Notifications & Reminders MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "areNotificationsEnabled" -> result.success(areNotificationsEnabled())
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 102)
                            result.success(true)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(true)
                }
                "scheduleReminder" -> scheduleReminder(call, result)
                "cancelReminder" -> cancelReminder(call, result)
                "cancelAllReminders" -> cancelAllReminders(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun areNotificationsEnabled(): Boolean {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && notificationManager != null) {
            notificationManager.areNotificationsEnabled()
        } else {
            true
        }
    }

    private fun openNotificationSettings(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun scheduleReminder(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val notificationId = call.argument<Int>("id") ?: run {
            result.error("ARG_ERR", "Missing id", null)
            return
        }
        val eventId = call.argument<String>("eventId") ?: ""
        val title = call.argument<String>("title") ?: "Event"
        val body = call.argument<String>("body") ?: ""
        val triggerTimeMillis = (call.argument<Number>("triggerTimeMillis"))?.toLong() ?: run {
            result.error("ARG_ERR", "Missing triggerTimeMillis", null)
            return
        }
        val colorHex = call.argument<String>("colorHex") ?: "#10B981"
        val minutesBefore = call.argument<Int>("minutesBefore") ?: 0

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager != null) {
            val alarmIntent = Intent(this, NotificationAlarmReceiver::class.java).apply {
                putExtra(NotificationAlarmReceiver.EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(NotificationAlarmReceiver.EXTRA_EVENT_ID, eventId)
                putExtra(NotificationAlarmReceiver.EXTRA_TITLE, title)
                putExtra(NotificationAlarmReceiver.EXTRA_BODY, body)
                putExtra(NotificationAlarmReceiver.EXTRA_COLOR_HEX, colorHex)
                putExtra(NotificationAlarmReceiver.EXTRA_MINUTES_BEFORE, minutesBefore)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                notificationId,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
                }
                // Persist for BootReceiver
                val prefs = getSharedPreferences("sectograph_reminders_prefs", Context.MODE_PRIVATE)
                val json = JSONObject().apply {
                    put("notificationId", notificationId)
                    put("eventId", eventId)
                    put("title", title)
                    put("body", body)
                    put("triggerEpochMs", triggerTimeMillis)
                    put("colorHex", colorHex)
                    put("minutesBefore", minutesBefore)
                }
                prefs.edit().putString(eventId, json.toString()).apply()
                result.success(true)
            } catch (e: Exception) {
                result.error("ALARM_ERROR", e.message, null)
            }
        } else {
            result.success(false)
        }
    }

    private fun cancelReminder(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val notificationId = call.argument<Int>("id") ?: run {
            result.error("ARG_ERR", "Missing id", null)
            return
        }
        val eventId = call.argument<String>("eventId") ?: ""

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val alarmIntent = Intent(this, NotificationAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            alarmIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null && alarmManager != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.cancel(notificationId)

        try {
            val prefs = getSharedPreferences("sectograph_reminders_prefs", Context.MODE_PRIVATE)
            prefs.edit().remove(eventId).apply()
        } catch (_: Exception) {}
        result.success(true)
    }

    private fun cancelAllReminders(result: MethodChannel.Result) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        try {
            val prefs = getSharedPreferences("sectograph_reminders_prefs", Context.MODE_PRIVATE)
            val allEntries = prefs.all
            for ((_, value) in allEntries) {
                if (value is String) {
                    try {
                        val json = JSONObject(value)
                        val notifId = json.getInt("notificationId")
                        val alarmIntent = Intent(this, NotificationAlarmReceiver::class.java)
                        val pendingIntent = PendingIntent.getBroadcast(
                            this,
                            notifId,
                            alarmIntent,
                            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                        )
                        if (pendingIntent != null && alarmManager != null) {
                            alarmManager.cancel(pendingIntent)
                            pendingIntent.cancel()
                        }
                        notificationManager?.cancel(notifId)
                    } catch (_: Exception) {}
                }
            }
            prefs.edit().clear().apply()
        } catch (_: Exception) {}
        result.success(true)
    }
}
