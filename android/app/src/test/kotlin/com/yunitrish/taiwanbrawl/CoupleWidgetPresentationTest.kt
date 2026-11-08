package com.yunitrish.taiwanbrawl

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class CoupleWidgetPresentationTest {
    @Test fun nameIsOptionalForOldSnapshotsAndClearedOutsideActiveState() {
        val today = now("Asia/Taipei", 2026, 11, 4)
        assertNull(CoupleWidgetPresentation.read(active(), today).partnerName)
        val named = active() + ("partnerName" to "Partner")
        assertEquals("Partner", CoupleWidgetPresentation.read(named, today).partnerName)
        assertEquals(setOf("schemaVersion", "startedOn", "lastSyncedAt"), CoupleWidgetPresentation.counterProjection(named)!!.keys)
        assertNull(CoupleWidgetPresentation.read(CoupleWidgetState.begin(named, null), today).partnerName)
        assertEquals("signedOut", CoupleWidgetPresentation.read(named + ("partnerName" to "bad\nname"), today).status)
    }
    @Test fun readOnlyProjectionContainsNoAccountOrRelationshipIdentity() {
        val projection = CoupleWidgetPresentation.counterProjection(active())!!
        assertEquals(setOf("schemaVersion", "startedOn", "lastSyncedAt"), projection.keys)
        assertNull(CoupleWidgetPresentation.counterProjection(CoupleWidgetState.begin(active(), null)))
        assertNull(CoupleWidgetPresentation.counterProjection(active() + ("token" to "unexpected")))
    }
    private fun now(zone: String, year: Int, month: Int, day: Int): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone(zone)).apply { clear(); set(year, month - 1, day, 12, 0) }
    private fun active(): Map<String, Any?> {
        val base = CoupleWidgetState.begin(null, "a".repeat(64))
        return CoupleWidgetState.replace(base, base + mapOf("requestSequence" to 1, "status" to "active",
            "relationshipId" to "r", "relationshipVersion" to 1, "startedOn" to "2026-11-01", "lastSyncedAt" to "2026-11-01T00:00:00Z"))
    }
    @Test fun offlineCountingHasNoTwentyFourHourExpiry() {
        assertEquals(4L, CoupleWidgetPresentation.read(active(), now("Asia/Taipei", 2026, 11, 4)).days)
        assertEquals(62L, CoupleWidgetPresentation.read(active(), now("Asia/Taipei", 2027, 1, 1)).days)
        assertEquals(1L, CoupleWidgetPresentation.read(active(), now("Pacific/Honolulu", 2026, 10, 31)).days)
    }
    @Test fun signedOutUnboundAndCorruptNeverRenderOldCount() {
        val today = now("Asia/Taipei", 2026, 11, 4)
        val signedOut = CoupleWidgetState.begin(active(), null)
        assertEquals(CoupleWidgetDisplay("signedOut"), CoupleWidgetPresentation.read(signedOut, today))
        assertEquals(CoupleWidgetDisplay("unbound"), CoupleWidgetPresentation.read(CoupleWidgetState.begin(signedOut, "a".repeat(64)), today))
        assertEquals(CoupleWidgetDisplay("signedOut"), CoupleWidgetPresentation.read(null, today))
        assertNull(CoupleWidgetPresentation.read(active() + ("startedOn" to "2026-02-30"), today).days)
        assertNull(CoupleWidgetPresentation.read(active() + ("credential" to "unexpected"), today).days)
    }
    @Test fun sameInstantUsesCurrentDeviceDate() {
        val taipei = now("Asia/Taipei", 2026, 11, 2)
        taipei.set(Calendar.HOUR_OF_DAY, 8)
        val hawaii = Calendar.getInstance(TimeZone.getTimeZone("Pacific/Honolulu"))
        hawaii.timeInMillis = taipei.timeInMillis
        assertEquals(2L, CoupleWidgetPresentation.read(active(), taipei).days)
        assertEquals(1L, CoupleWidgetPresentation.read(active(), hawaii).days)
    }
    @Test fun productionCalendarHandlesDstLeapDayAndYearBoundary() {
        assertEquals(3L, CoupleDaysCalendar.count("2026-03-07", now("America/New_York", 2026, 3, 9)))
        assertEquals(3L, CoupleDaysCalendar.count("2026-10-31", now("America/New_York", 2026, 11, 2)))
        assertEquals(3L, CoupleDaysCalendar.count("2024-02-28", now("Asia/Taipei", 2024, 3, 1)))
        assertEquals(2L, CoupleDaysCalendar.count("2025-12-31", now("Asia/Taipei", 2026, 1, 1)))
    }
}
