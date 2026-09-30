package com.ksmxtech.sectograph_mcp

data class NeedleWarpBreakpoint(
    val naturalDeg: Double,
    val displayDeg: Double
)

/**
 * High-performance piecewise-linear coordinate interpolator (§6.2, RC5, RC6, RC10).
 *
 * Maps linear clock time angle [0, 360) to stretched dial display angle [0, 360)
 * using the precomputed warp breakpoints from frames.json.
 * Validated against test/fixtures/warp_interpolation_vectors.json for 100% parity with Dart WarpMap.
 */
object NeedleInterpolator {

    fun interpolate(naturalDeg: Double, breakpoints: List<NeedleWarpBreakpoint>): Double {
        if (breakpoints.isEmpty()) {
            return (naturalDeg % 360.0 + 360.0) % 360.0
        }
        if (Math.abs(naturalDeg - 360.0) < 1e-9) {
            return breakpoints.last().displayDeg
        }
        val norm = (naturalDeg % 360.0 + 360.0) % 360.0
        if (breakpoints.size < 2) return norm

        if (norm == 0.0) return breakpoints.first().displayDeg

        for (i in 0 until breakpoints.size - 1) {
            val p0 = breakpoints[i]
            val p1 = breakpoints[i + 1]

            if (norm >= p0.naturalDeg && norm <= p1.naturalDeg) {
                val natSpan = p1.naturalDeg - p0.naturalDeg
                if (natSpan <= 1e-9) return p0.displayDeg

                val t = (norm - p0.naturalDeg) / natSpan
                val dispSpan = p1.displayDeg - p0.displayDeg
                return p0.displayDeg + t * dispSpan
            }
        }

        return norm
    }
}
