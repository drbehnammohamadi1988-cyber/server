package com.atelier.vinyl

import com.atelier.vinyl.ui.components.OrbitalGeometry
import com.atelier.vinyl.ui.components.TurntableKinematics
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TurntablePhysicsTest {

    @Test
    fun rpm33_speed_matches_200_degrees_per_second() {
        assertEquals(200f, TurntableKinematics.RPM_33_DEG_PER_SEC, 0.01f)
    }

    @Test
    fun tonearm_sweeps_from_outer_to_inner_groove() {
        val start = TurntableKinematics.targetArmAngle(0f)
        val mid = TurntableKinematics.targetArmAngle(0.5f)
        val end = TurntableKinematics.targetArmAngle(1f)
        assertEquals(TurntableKinematics.ARM_OUTER_GROOVE_DEG, start, 0.001f)
        assertEquals(TurntableKinematics.ARM_INNER_GROOVE_DEG, end, 0.001f)
        assertTrue(mid > start && mid < end)
    }

    @Test
    fun orbital_wheel_places_center_item_furthest_left_in_ltr_and_tilts_neighbors() {
        val center = OrbitalGeometry.computePlacement(0f, 400f, 700f, isRtl = false, reduceMotion = false)
        val above = OrbitalGeometry.computePlacement(-1f, 400f, 700f, isRtl = false, reduceMotion = false)
        val below = OrbitalGeometry.computePlacement(1f, 400f, 700f, isRtl = false, reduceMotion = false)

        assertEquals(0f, center.tiltDeg, 0.001f)
        assertEquals(1f, center.capsuleFactor, 0.001f)
        assertTrue(above.xPx > center.xPx)
        assertTrue(below.xPx > center.xPx)
        assertTrue(above.tiltDeg > 0f)
        assertTrue(below.tiltDeg < 0f)
    }
}
