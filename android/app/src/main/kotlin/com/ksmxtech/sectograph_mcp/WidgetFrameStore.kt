package com.ksmxtech.sectograph_mcp

import android.content.Context
import android.content.res.Configuration
import org.json.JSONObject
import java.io.File

data class CurrentPointer(
    val currentVersion: String,
    val tzid: String,
    val validUntilMs: Long,
    val updatedAtMs: Long
)

data class FrameCenterInfo(
    val mode: String,
    val activeTitle: String?,
    val activeCategory: String?,
    val remainingDuration: String?
)

data class FrameInfo(
    val fromMs: Long,
    val toMs: Long,
    val file: String,
    val signature: String,
    val layoutSignature: String,
    val warpKey: String,
    val warp: List<NeedleWarpBreakpoint>,
    val center: FrameCenterInfo,
    val activeEventId: String?,
    val activeEventEndMs: Long
)

data class FrameStripPlan(
    val dataVersion: String,
    val tzid: String,
    val validUntilMs: Long,
    val themeVariants: List<String>,
    val frames: List<FrameInfo>
)

data class ActiveFrameResult(
    val frame: FrameInfo,
    val bitmapFile: File,
    val isStale: Boolean,
    val tzid: String
)

/**
 * Native manager and cache for precomputed Widget Frame Strips (§6.1, §6.2, RC5, RC6, RC10).
 *
 * Reads frames.json from `<filesDir>/widget_frames/<version>/`, caches the parsed plan,
 * selects the active frame for any given wall-clock time, and monitors data freshness.
 */
object WidgetFrameStore {

    private var cachedPlan: FrameStripPlan? = null
    private var cachedVersion: String? = null
    private var lastFramesJsonModified: Long = 0L

    fun getFramesBaseDir(context: Context): File {
        return File(context.filesDir, "widget_frames")
    }

    fun loadCurrentPointer(context: Context): CurrentPointer? {
        val baseDir = getFramesBaseDir(context)
        val pointerFile = File(baseDir, "current.json")
        if (!pointerFile.exists() || !pointerFile.canRead()) return null

        return try {
            val json = JSONObject(pointerFile.readText())
            CurrentPointer(
                currentVersion = json.getString("currentVersion"),
                tzid = json.optString("tzid", "UTC"),
                validUntilMs = json.optLong("validUntilMs", 0L),
                updatedAtMs = json.optLong("updatedAtMs", 0L)
            )
        } catch (_: Exception) {
            null
        }
    }

    @Synchronized
    fun loadFramesPlan(context: Context, version: String): FrameStripPlan? {
        val baseDir = getFramesBaseDir(context)
        val versionDir = File(baseDir, version)
        val framesJsonFile = File(versionDir, "frames.json")
        if (!framesJsonFile.exists() || !framesJsonFile.canRead()) return null

        val lastMod = framesJsonFile.lastModified()
        if (cachedVersion == version && cachedPlan != null && lastFramesJsonModified == lastMod) {
            return cachedPlan
        }

        return try {
            val json = JSONObject(framesJsonFile.readText())
            val dataVersion = json.getString("dataVersion")
            val tzid = json.optString("tzid", "UTC")
            val validUntilMs = json.optLong("validUntilMs", 0L)

            val themeVariantsArr = json.optJSONArray("themeVariants")
            val themeVariants = mutableListOf<String>()
            if (themeVariantsArr != null) {
                for (i in 0 until themeVariantsArr.length()) {
                    themeVariants.add(themeVariantsArr.getString(i))
                }
            }

            val framesArr = json.getJSONArray("frames")
            val frames = mutableListOf<FrameInfo>()

            for (i in 0 until framesArr.length()) {
                val fObj = framesArr.getJSONObject(i)
                val fromMs = fObj.getLong("fromMs")
                val toMs = fObj.getLong("toMs")
                val file = fObj.getString("file")
                val signature = fObj.optString("signature", "")
                val layoutSignature = fObj.optString("layoutSignature", "")
                val warpKey = fObj.optString("warpKey", "")

                val warpArr = fObj.optJSONArray("warp")
                val warp = mutableListOf<NeedleWarpBreakpoint>()
                if (warpArr != null) {
                    for (j in 0 until warpArr.length()) {
                        val pair = warpArr.getJSONArray(j)
                        warp.add(NeedleWarpBreakpoint(pair.getDouble(0), pair.getDouble(1)))
                    }
                }

                val cObj = fObj.optJSONObject("center")
                val centerInfo = FrameCenterInfo(
                    mode = cObj?.optString("mode", "digital") ?: "digital",
                    activeTitle = cObj?.optString("activeTitle")?.takeIf { it.isNotEmpty() && it != "null" },
                    activeCategory = cObj?.optString("activeCategory")?.takeIf { it.isNotEmpty() && it != "null" },
                    remainingDuration = cObj?.optString("remainingDuration")?.takeIf { it.isNotEmpty() && it != "null" }
                )

                val activeEventId = fObj.optString("activeEventId").takeIf { it.isNotEmpty() && it != "null" }
                val activeEventEndMs = fObj.optLong("activeEventEndMs", 0L)

                frames.add(
                    FrameInfo(
                        fromMs = fromMs,
                        toMs = toMs,
                        file = file,
                        signature = signature,
                        layoutSignature = layoutSignature,
                        warpKey = warpKey,
                        warp = warp,
                        center = centerInfo,
                        activeEventId = activeEventId,
                        activeEventEndMs = activeEventEndMs
                    )
                )
            }

            val plan = FrameStripPlan(
                dataVersion = dataVersion,
                tzid = tzid,
                validUntilMs = validUntilMs,
                themeVariants = themeVariants,
                frames = frames
            )

            cachedPlan = plan
            cachedVersion = version
            lastFramesJsonModified = lastMod
            plan
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Resolves the active frame for the given instant, selecting the corresponding light/dark PNG.
     */
    fun getActiveFrame(context: Context, nowMs: Long = System.currentTimeMillis()): ActiveFrameResult? {
        val pointer = loadCurrentPointer(context) ?: return null
        val plan = loadFramesPlan(context, pointer.currentVersion) ?: return null

        if (plan.frames.isEmpty()) return null

        // Find frame matching nowMs: [fromMs, toMs)
        var matchedFrame: FrameInfo? = null
        for (f in plan.frames) {
            if (nowMs >= f.fromMs && nowMs < f.toMs) {
                matchedFrame = f
                break
            }
        }

        // Boundary fallback
        if (matchedFrame == null) {
            matchedFrame = if (nowMs < plan.frames.first().fromMs) {
                plan.frames.first()
            } else {
                plan.frames.last()
            }
        }

        val isStale = (nowMs > plan.validUntilMs)

        // Select light vs dark variant based on current Android system night mode
        val isNightMode = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val variant = if (isNightMode) "dark" else "light"

        val versionDir = File(getFramesBaseDir(context), pointer.currentVersion)
        var imageFile = File(versionDir, "$variant/${matchedFrame.file}")

        if (!imageFile.exists() || !imageFile.canRead()) {
            val fallbackVariant = if (isNightMode) "light" else "dark"
            val fallbackFile = File(versionDir, "$fallbackVariant/${matchedFrame.file}")
            if (fallbackFile.exists() && fallbackFile.canRead()) {
                imageFile = fallbackFile
            } else {
                val flatFile = File(versionDir, matchedFrame.file)
                if (flatFile.exists() && flatFile.canRead()) {
                    imageFile = flatFile
                }
            }
        }

        return ActiveFrameResult(
            frame = matchedFrame,
            bitmapFile = imageFile,
            isStale = isStale,
            tzid = plan.tzid
        )
    }

    @Synchronized
    fun invalidateCache() {
        cachedPlan = null
        cachedVersion = null
        lastFramesJsonModified = 0L
    }
}
