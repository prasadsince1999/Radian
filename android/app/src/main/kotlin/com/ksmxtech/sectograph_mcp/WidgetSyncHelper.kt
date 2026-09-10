package com.ksmxtech.sectograph_mcp

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import java.io.File
import java.io.FileOutputStream

/**
 * Encapsulates AppWidget bitmap persistence, preference updates, widget pinning,
 * and battery optimization configurations.
 */
class WidgetSyncHelper(private val context: Context) {

    fun updateWidget(
        title: String,
        time: String,
        status: String,
        date: String,
        dialBytes: ByteArray?
    ): Boolean {
        // Save image atomically if present
        if (dialBytes != null && dialBytes.isNotEmpty()) {
            try {
                val tempFile = File(context.filesDir, "widget_dial_tmp.png")
                val targetFile = File(context.filesDir, "widget_dial.png")
                FileOutputStream(tempFile).use { fos ->
                    fos.write(dialBytes)
                    fos.flush()
                }
                tempFile.renameTo(targetFile)
            } catch (_: Exception) {}
        }

        // Save prefs
        val prefs = context.getSharedPreferences(SectographWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(SectographWidgetProvider.KEY_TITLE, title)
            .putString(SectographWidgetProvider.KEY_TIME, time)
            .putString(SectographWidgetProvider.KEY_STATUS, status)
            .putString(SectographWidgetProvider.KEY_DATE, date)
            .apply()

        // Trigger native AppWidget update and schedule minute loop
        SectographWidgetProvider.updateAll(context)
        SectographWidgetProvider.scheduleNextMinuteAlarm(context)
        return true
    }

    fun pinWidget(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val myProvider = ComponentName(context, SectographWidgetProvider::class.java)
            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                appWidgetManager.requestPinAppWidget(myProvider, null, null)
                return true
            }
        }
        return false
    }

    fun isBatteryOptimizationIgnored(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && powerManager != null) {
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true
        }
    }

    fun requestIgnoreBatteryOptimization(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val alreadyIgnored = powerManager?.isIgnoringBatteryOptimizations(context.packageName) == true
            if (alreadyIgnored) {
                return openBatterySettings(activity)
            }
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {
                return openBatterySettings(activity)
            }
        }
        return false
    }

    fun openBatterySettings(activity: Activity): Boolean {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {
                return false
            }
        }
    }
}
