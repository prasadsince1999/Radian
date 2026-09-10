package com.ksmxtech.sectograph_mcp

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.health.connect.HealthConnectException
import android.health.connect.HealthConnectManager
import android.health.connect.ReadRecordsRequestUsingFilters
import android.health.connect.ReadRecordsResponse
import android.health.connect.TimeInstantRangeFilter
import android.health.connect.datatypes.ActiveCaloriesBurnedRecord
import android.health.connect.datatypes.DistanceRecord
import android.health.connect.datatypes.ExerciseSessionRecord
import android.health.connect.datatypes.HydrationRecord
import android.health.connect.datatypes.SleepSessionRecord
import android.health.connect.datatypes.StepsRecord
import android.health.connect.datatypes.TotalCaloriesBurnedRecord
import android.net.Uri
import android.os.Build
import android.os.OutcomeReceiver
import android.provider.Settings
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Encapsulates Android Health Connect queries, permissions, and synchronization
 * with the device hardware step sensor.
 */
class HealthConnectHelper(
    private val activity: Activity,
    private val stepSensorHelper: StepSensorHelper
) {
    private val healthExecutor = Executors.newFixedThreadPool(2)

    fun isHealthConnectAvailable(): Boolean {
        val pm = activity.packageManager
        val intent = Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
        val activities = pm.queryIntentActivities(intent, 0)
        return activities.isNotEmpty() || Build.VERSION.SDK_INT >= 34
    }

    fun hasHealthPermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= 34) {
            val perms = arrayOf(
                "android.permission.health.READ_STEPS",
                "android.permission.health.READ_SLEEP",
                "android.permission.health.READ_EXERCISE"
            )
            val hcGranted = perms.all {
                activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
            }
            val actGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                activity.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
            } else true
            return hcGranted || actGranted
        }
        return false
    }

    fun requestHealthPermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= 34) {
            try {
                val perms = mutableListOf(
                    "android.permission.health.READ_STEPS",
                    "android.permission.health.READ_SLEEP",
                    "android.permission.health.READ_EXERCISE",
                    "android.permission.health.READ_ACTIVE_CALORIES_BURNED",
                    "android.permission.health.READ_TOTAL_CALORIES_BURNED",
                    "android.permission.health.READ_DISTANCE",
                    "android.permission.health.READ_HYDRATION",
                    "android.permission.health.READ_HEART_RATE"
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    perms.add(Manifest.permission.ACTIVITY_RECOGNITION)
                }
                activity.requestPermissions(perms.toTypedArray(), 101)
                return true
            } catch (_: Exception) {}
        }
        return openHealthConnectSettings()
    }

    fun openHealthConnectSettings(): Boolean {
        try {
            val intent = Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                putExtra(Intent.EXTRA_PACKAGE_NAME, activity.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}

        try {
            val intent = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {}

        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${activity.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            return true
        } catch (_: Exception) {
            return false
        }
    }

    fun fetchDailyHealthSummary(dateArg: String?, callback: (Map<String, Any?>) -> Unit) {
        healthExecutor.execute {
            try {
                val zoneId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ZoneId.systemDefault() else null
                val localDate = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && zoneId != null) {
                    try {
                        if (dateArg != null && dateArg.contains("T")) {
                            Instant.parse(dateArg).atZone(zoneId).toLocalDate()
                        } else if (dateArg != null && dateArg.length >= 10) {
                            LocalDate.parse(dateArg.substring(0, 10))
                        } else {
                            LocalDate.now(zoneId)
                        }
                    } catch (_: Exception) {
                        LocalDate.now(zoneId)
                    }
                } else null

                var hcSteps = 0L
                var activeCal = 0.0
                var totalCal = 0.0
                var distance = 0.0
                var sleepMinutes = 0
                var sleepStartStr: String? = null
                var sleepEndStr: String? = null
                var hydration = 0.0
                val exerciseSessions = mutableListOf<Map<String, Any>>()

                if (Build.VERSION.SDK_INT >= 34 && localDate != null && zoneId != null) {
                    val startInstant = localDate.atStartOfDay(zoneId).toInstant()
                    val endInstant = localDate.plusDays(1).atStartOfDay(zoneId).toInstant().minusMillis(1)
                    val healthConnectManager = activity.getSystemService(HealthConnectManager::class.java)

                    if (healthConnectManager != null) {
                        // 1. Steps
                        try {
                            val latch = CountDownLatch(1)
                            val req = ReadRecordsRequestUsingFilters.Builder(StepsRecord::class.java)
                                .setTimeRangeFilter(
                                    TimeInstantRangeFilter.Builder()
                                        .setStartTime(startInstant)
                                        .setEndTime(endInstant)
                                        .build()
                                )
                                .build()
                            healthConnectManager.readRecords(
                                req,
                                healthExecutor,
                                object : OutcomeReceiver<ReadRecordsResponse<StepsRecord>, HealthConnectException> {
                                    override fun onResult(res: ReadRecordsResponse<StepsRecord>) {
                                        for (rec in res.records) {
                                            hcSteps += rec.count
                                        }
                                        latch.countDown()
                                    }
                                    override fun onError(err: HealthConnectException) {
                                        latch.countDown()
                                    }
                                }
                            )
                            latch.await(2, TimeUnit.SECONDS)
                        } catch (_: Exception) {}

                        // 2. Active Calories
                        try {
                            val latch = CountDownLatch(1)
                            val req = ReadRecordsRequestUsingFilters.Builder(ActiveCaloriesBurnedRecord::class.java)
                                .setTimeRangeFilter(
                                    TimeInstantRangeFilter.Builder()
                                        .setStartTime(startInstant)
                                        .setEndTime(endInstant)
                                        .build()
                                )
                                .build()
                            healthConnectManager.readRecords(
                                req,
                                healthExecutor,
                                object : OutcomeReceiver<ReadRecordsResponse<ActiveCaloriesBurnedRecord>, HealthConnectException> {
                                    override fun onResult(res: ReadRecordsResponse<ActiveCaloriesBurnedRecord>) {
                                        for (rec in res.records) {
                                            activeCal += rec.energy.inCalories / 1000.0
                                        }
                                        latch.countDown()
                                    }
                                    override fun onError(err: HealthConnectException) {
                                        latch.countDown()
                                    }
                                }
                            )
                            latch.await(1, TimeUnit.SECONDS)
                        } catch (_: Exception) {}

                        // 3. Total Calories
                        try {
                            val latch = CountDownLatch(1)
                            val req = ReadRecordsRequestUsingFilters.Builder(TotalCaloriesBurnedRecord::class.java)
                                .setTimeRangeFilter(
                                    TimeInstantRangeFilter.Builder()
                                        .setStartTime(startInstant)
                                        .setEndTime(endInstant)
                                        .build()
                                )
                                .build()
                            healthConnectManager.readRecords(
                                req,
                                healthExecutor,
                                object : OutcomeReceiver<ReadRecordsResponse<TotalCaloriesBurnedRecord>, HealthConnectException> {
                                    override fun onResult(res: ReadRecordsResponse<TotalCaloriesBurnedRecord>) {
                                        for (rec in res.records) {
                                            totalCal += rec.energy.inCalories / 1000.0
                                        }
                                        latch.countDown()
                                    }
                                    override fun onError(err: HealthConnectException) {
                                        latch.countDown()
                                    }
                                }
                            )
                            latch.await(1, TimeUnit.SECONDS)
                        } catch (_: Exception) {}

                        // 4. Distance
                        try {
                            val latch = CountDownLatch(1)
                            val req = ReadRecordsRequestUsingFilters.Builder(DistanceRecord::class.java)
                                .setTimeRangeFilter(
                                    TimeInstantRangeFilter.Builder()
                                        .setStartTime(startInstant)
                                        .setEndTime(endInstant)
                                        .build()
                                )
                                .build()
                            healthConnectManager.readRecords(
                                req,
                                healthExecutor,
                                object : OutcomeReceiver<ReadRecordsResponse<DistanceRecord>, HealthConnectException> {
                                    override fun onResult(res: ReadRecordsResponse<DistanceRecord>) {
                                        for (rec in res.records) {
                                            distance += rec.distance.inMeters
                                        }
                                        latch.countDown()
                                    }
                                    override fun onError(err: HealthConnectException) {
                                        latch.countDown()
                                    }
                                }
                            )
                            latch.await(1, TimeUnit.SECONDS)
                        } catch (_: Exception) {}

                        // 5. Sleep Sessions (look back 18h for previous night sleep)
                        try {
                            val latch = CountDownLatch(1)
                            val sleepStartFilter = startInstant.minus(18, ChronoUnit.HOURS)
                            val req = ReadRecordsRequestUsingFilters.Builder(SleepSessionRecord::class.java)
                                .setTimeRangeFilter(
                                    TimeInstantRangeFilter.Builder()
                                        .setStartTime(sleepStartFilter)
                                        .setEndTime(endInstant)
                                        .build()
                                )
                                .build()
                            healthConnectManager.readRecords(
                                req,
                                healthExecutor,
                                object : OutcomeReceiver<ReadRecordsResponse<SleepSessionRecord>, HealthConnectException> {
                                    override fun onResult(res: ReadRecordsResponse<SleepSessionRecord>) {
                                        var maxDur = 0L
                                        for (rec in res.records) {
                                            val dur = Duration.between(rec.startTime, rec.endTime).toMinutes()
                                            if (dur > maxDur) {
                                                maxDur = dur
                                                sleepStartStr = rec.startTime.toString()
                                                sleepEndStr = rec.endTime.toString()
                                            }
                                        }
                                        sleepMinutes = maxDur.toInt()
                                        latch.countDown()
                                    }
                                    override fun onError(err: HealthConnectException) {
                                        latch.countDown()
                                    }
                                }
                            )
                            latch.await(1, TimeUnit.SECONDS)
                        } catch (_: Exception) {}

                        // 6. Exercise Sessions
                        try {
                            val latch = CountDownLatch(1)
                            val req = ReadRecordsRequestUsingFilters.Builder(ExerciseSessionRecord::class.java)
                                .setTimeRangeFilter(
                                    TimeInstantRangeFilter.Builder()
                                        .setStartTime(startInstant)
                                        .setEndTime(endInstant)
                                        .build()
                                )
                                .build()
                            healthConnectManager.readRecords(
                                req,
                                healthExecutor,
                                object : OutcomeReceiver<ReadRecordsResponse<ExerciseSessionRecord>, HealthConnectException> {
                                    override fun onResult(res: ReadRecordsResponse<ExerciseSessionRecord>) {
                                        for (rec in res.records) {
                                            exerciseSessions.add(mapOf(
                                                "id" to rec.metadata.id,
                                                "title" to (rec.title ?: "Workout"),
                                                "type" to "workout",
                                                "start" to rec.startTime.toString(),
                                                "end" to rec.endTime.toString(),
                                                "caloriesBurned" to 0.0,
                                                "distanceMeters" to 0.0,
                                                "sourceApp" to "Health Connect"
                                            ))
                                        }
                                        latch.countDown()
                                    }
                                    override fun onError(err: HealthConnectException) {
                                        latch.countDown()
                                    }
                                }
                            )
                            latch.await(1, TimeUnit.SECONDS)
                        } catch (_: Exception) {}

                        // 7. Hydration
                        try {
                            val latch = CountDownLatch(1)
                            val req = ReadRecordsRequestUsingFilters.Builder(HydrationRecord::class.java)
                                .setTimeRangeFilter(
                                    TimeInstantRangeFilter.Builder()
                                        .setStartTime(startInstant)
                                        .setEndTime(endInstant)
                                        .build()
                                )
                                .build()
                            healthConnectManager.readRecords(
                                req,
                                healthExecutor,
                                object : OutcomeReceiver<ReadRecordsResponse<HydrationRecord>, HealthConnectException> {
                                    override fun onResult(res: ReadRecordsResponse<HydrationRecord>) {
                                        for (rec in res.records) {
                                            hydration += rec.volume.inLiters * 1000.0
                                        }
                                        latch.countDown()
                                    }
                                    override fun onError(err: HealthConnectException) {
                                        latch.countDown()
                                    }
                                }
                            )
                            latch.await(1, TimeUnit.SECONDS)
                        } catch (_: Exception) {}
                    }
                }

                // Sync with hardware step sensor
                stepSensorHelper.syncStepCount(hcSteps)
                val sensorSteps = stepSensorHelper.getTodayStepCount()
                val finalSteps = Math.max(hcSteps, sensorSteps)

                val effectiveActiveCal = if (activeCal > 0.0) activeCal else (finalSteps * 0.04)
                val effectiveTotalCal = if (totalCal > 0.0) totalCal else (effectiveActiveCal + 1400.0)
                val effectiveDist = if (distance > 0.0) distance else (finalSteps * 0.762)
                val dateFormatted = if (localDate != null) "${localDate}T00:00:00.000" else (dateArg ?: "2026-09-09T00:00:00.000")

                val resultMap = HashMap<String, Any?>().apply {
                    put("date", dateFormatted)
                    put("steps", finalSteps.toInt())
                    put("activeCalories", effectiveActiveCal)
                    put("totalCalories", effectiveTotalCal)
                    put("distanceMeters", effectiveDist)
                    put("sleepDurationMinutes", sleepMinutes)
                    put("sleepStart", sleepStartStr)
                    put("sleepEnd", sleepEndStr)
                    put("deepSleepMinutes", if (sleepMinutes > 60) (sleepMinutes * 0.22).toInt() else 0)
                    put("remSleepMinutes", if (sleepMinutes > 60) (sleepMinutes * 0.20).toInt() else 0)
                    put("hydrationMl", hydration)
                    put("restingHeartRate", 70)
                    put("exerciseSessions", exerciseSessions)
                    put("lastSyncTime", if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Instant.now().toString() else "")
                }

                activity.runOnUiThread {
                    callback(resultMap)
                }
            } catch (e: Exception) {
                activity.runOnUiThread {
                    callback(emptyMap())
                }
            }
        }
    }
}
