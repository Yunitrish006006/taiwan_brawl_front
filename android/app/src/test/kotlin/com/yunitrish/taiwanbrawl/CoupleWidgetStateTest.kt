package com.yunitrish.taiwanbrawl

import org.junit.Assert.*
import org.junit.Test

class CoupleWidgetStateTest {
    private val scope = "a".repeat(64)
    private fun active(state: Map<String, Any?>, sequence: Int = 1) = state + mapOf(
        "status" to "active", "requestSequence" to sequence, "relationshipId" to "r", "relationshipVersion" to 1,
        "startedOn" to "2026-11-01", "lastSyncedAt" to "2026-11-01T00:00:00Z")
    @Test fun logoutAndRestartRejectOldWrites() {
        val first = CoupleWidgetState.begin(null, scope)
        val saved = CoupleWidgetState.replace(first, active(first))
        val logout = CoupleWidgetState.begin(saved, null)
        assertNull(logout["startedOn"])
        assertEquals("signedOut", logout["status"])
        assertThrows(IllegalArgumentException::class.java) { CoupleWidgetState.replace(logout, active(first, 2)) }
        val restarted = CoupleWidgetState.begin(logout, scope)
        assertTrue((restarted["sessionGeneration"] as Long) > (first["sessionGeneration"] as Long))
        assertThrows(IllegalArgumentException::class.java) { CoupleWidgetState.replace(restarted, active(first, 3)) }
    }
    @Test fun sequenceAndScopeAreValidatedIndependently() {
        val state = CoupleWidgetState.begin(null, scope)
        val saved = CoupleWidgetState.replace(state, active(state, 5))
        assertThrows(IllegalArgumentException::class.java) { CoupleWidgetState.replace(saved, active(state, 4)) }
        assertThrows(IllegalArgumentException::class.java) { CoupleWidgetState.replace(saved, active(state, 6) + ("accountScope" to "b".repeat(64))) }
        assertEquals("active", CoupleWidgetState.replace(saved, active(state, 6))["status"])
    }
    @Test fun invalidDatesUnknownFieldsAndUnclearedEmptyStatesAreRejected() {
        val state = CoupleWidgetState.begin(null, scope)
        assertThrows(IllegalArgumentException::class.java) { CoupleWidgetState.replace(state, active(state) + ("startedOn" to "2026-02-30")) }
        assertThrows(IllegalArgumentException::class.java) { CoupleWidgetState.replace(state, active(state) + ("token" to "secret")) }
        assertThrows(IllegalArgumentException::class.java) { CoupleWidgetState.replace(state, active(state) + ("status" to "unbound")) }
    }
}
