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
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

/**
 * Main Android activity coordinating Flutter engine MethodChannels,
 * widget syncing, Health Connect, hardware step tracking, exact notification alarms,
 * and seamless In-App OTA Updates.
 */
class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.ksmxtech.sectograph_mcp/widget"
    private val NOTIFICATIONS_CHANNEL = "com.ksmxtech.sectograph_mcp/notifications"
    private val UPDATER_CHANNEL = "com.ksmxtech.sectograph_mcp/updater"

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
        if (action == "open_update" || intent.action == "open_update") {
            pendingAction = "open_update"
            methodChannel?.invokeMethod("onOpenUpdate", intent.getStringExtra("version") ?: "")
        }

        // Handle URI schemes: radian://new_block, radian://today, radian://dial, radian://event?id=...
        val dataUri = intent.data
        if (dataUri != null && dataUri.scheme == "radian") {
            when (dataUri.host) {
                "new_block" -> {
                    pendingAction = "add_block"
                    methodChannel?.invokeMethod("onWidgetAction", "add_block")
                }
                "today", "dial" -> {
                    methodChannel?.invokeMethod("onWidgetAction", "open_today")
                }
                "event" -> {
                    val eventId = dataUri.getQueryParameter("id")
                    if (!eventId.isNullOrEmpty()) {
                        methodChannel?.invokeMethod("onOpenEvent", eventId)
                    }
                }
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
                        val is24HourMode = call.argument<Boolean>("is24HourMode") ?: false
                        val dialBgColor = (call.argument<Number>("dialBgColor"))?.toInt() ?: 0
                        val eventsJson = call.argument<String>("eventsJson")
                        val timestamp = (call.argument<Number>("timestamp"))?.toLong() ?: System.currentTimeMillis()
                        result.success(
                            widgetSyncHelper.updateWidget(
                                title,
                                time,
                                status,
                                date,
                                dialBytes,
                                is24HourMode,
                                dialBgColor,
                                eventsJson,
                                timestamp
                            )
                        )
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

        // 3. In-App OTA Updater MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCacheApkPath" -> {
                    val updateDir = File(cacheDir, "updates").apply { if (!exists()) mkdirs() }
                    val apkFile = File(updateDir, "Radian-update.apk")
                    result.success(apkFile.absolutePath)
                }
                "canInstallPackages" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath") ?: run {
                        result.error("ARG_ERR", "Missing filePath", null)
                        return@setMethodCallHandler
                    }
                    val apkFile = File(filePath)
                    if (!apkFile.exists()) {
                        result.error("NOT_FOUND", "File does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val contentUri = FileProvider.getUriForFile(
                            applicationContext,
                            "$packageName.fileprovider",
                            apkFile
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(installIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERR", e.message, null)
                    }
                }
                "showUpdateNotification" -> {
                    val title = call.argument<String>("title") ?: "Radian Update Available"
                    val body = call.argument<String>("body") ?: "A new update is ready to install."
                    val version = call.argument<String>("version") ?: ""

                    val notifyIntent = Intent(this, MainActivity::class.java).apply {
                        action = "open_update"
                        putExtra("version", version)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        this,
                        9999,
                        notifyIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val notification = NotificationCompat.Builder(this, NotificationAlarmReceiver.CHANNEL_ID)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setAutoCancel(true)
                        .setContentIntent(pendingIntent)
                        .build()

                    notificationManager.notify(9999, notification)
                    result.success(true)
                }
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
