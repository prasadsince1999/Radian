package com.ksmxtech.sectograph_mcp

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class NeedleInterpolatorTest {

    @Test
    fun testWarpInterpolationSharedVectors() {
        val candidates = listOf(
            File("../../test/fixtures/warp_interpolation_vectors.json"),
            File("test/fixtures/warp_interpolation_vectors.json"),
            File("../test/fixtures/warp_interpolation_vectors.json"),
            File("c:/Projects/KSM x Tech - Projects/sectograph_mcp/test/fixtures/warp_interpolation_vectors.json")
        )
        val file = candidates.find { it.exists() }
        assertTrue("Test vectors file must exist in one of the locations", file != null && file.exists())

        val json = JSONObject(file!!.readText())
        val suites = json.getJSONArray("testSuites")

        for (i in 0 until suites.length()) {
            val suite = suites.getJSONObject(i)
            val name = suite.getString("name")
            val rawBps = suite.getJSONArray("breakpoints")
            val breakpoints = mutableListOf<NeedleWarpBreakpoint>()

            for (j in 0 until rawBps.length()) {
                val pair = rawBps.getJSONArray(j)
                breakpoints.add(NeedleWarpBreakpoint(pair.getDouble(0), pair.getDouble(1)))
            }

            val cases = suite.getJSONArray("cases")
            for (k in 0 until cases.length()) {
                val c = cases.getJSONObject(k)
                val input = c.getDouble("inputNaturalDeg")
                val expected = c.getDouble("expectedDisplayDeg")

                val actual = NeedleInterpolator.interpolate(input, breakpoints)
                assertEquals(
                    "Suite \"$name\" failed for natural angle $input°",
                    expected,
                    actual,
                    0.001
                )
            }
        }
    }
}
