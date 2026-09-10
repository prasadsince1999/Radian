package com.ksmxtech.sectograph_mcp

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import java.time.LocalDate

/**
 * Handles device hardware step sensor registration, midnight baseline rollover,
 * and persistent storage of daily step counts.
 */
class StepSensorHelper(private val context: Context) : SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null

    fun init() {
        try {
            sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            stepSensor?.let {
                sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            }
        } catch (_: Exception) {}
    }

    fun onResume() {
        stepSensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    fun onPause() {
        try {
            sensorManager?.unregisterListener(this)
        } catch (_: Exception) {}
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        val totalBootSteps = event.values[0].toLong()
        try {
            val todayStr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                LocalDate.now().toString()
            } else {
                java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
            }
            val prefs = context.getSharedPreferences("sectograph_health_prefs", Context.MODE_PRIVATE)
            val savedDate = prefs.getString("sensor_step_date", null)
            var baseline = prefs.getLong("sensor_step_baseline", -1L)

            if (savedDate != todayStr || baseline < 0 || totalBootSteps < baseline) {
                val existingTodaySteps = if (savedDate == todayStr) prefs.getLong("sensor_today_steps", 0L) else 0L
                baseline = totalBootSteps - existingTodaySteps
                prefs.edit()
                    .putString("sensor_step_date", todayStr)
                    .putLong("sensor_step_baseline", baseline)
                    .putLong("sensor_today_steps", existingTodaySteps)
                    .apply()
            } else {
                val todaySteps = totalBootSteps - baseline
                prefs.edit()
                    .putLong("sensor_today_steps", todaySteps)
                    .apply()
            }
        } catch (_: Exception) {}
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun getTodayStepCount(): Long {
        val prefs = context.getSharedPreferences("sectograph_health_prefs", Context.MODE_PRIVATE)
        return prefs.getLong("sensor_today_steps", 0L)
    }

    fun syncStepCount(count: Long) {
        val prefs = context.getSharedPreferences("sectograph_health_prefs", Context.MODE_PRIVATE)
        val current = prefs.getLong("sensor_today_steps", 0L)
        if (count > current) {
            prefs.edit().putLong("sensor_today_steps", count).apply()
        }
    }
}
