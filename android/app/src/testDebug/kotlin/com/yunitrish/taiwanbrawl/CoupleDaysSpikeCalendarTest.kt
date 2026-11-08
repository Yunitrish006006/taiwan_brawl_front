package com.yunitrish.taiwanbrawl

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class CoupleDaysSpikeCalendarTest {
    private fun count(start: String, today: String, zone: String = "Asia/Taipei"): Long {
        val parts = today.split("-").map { it.toInt() }
        val calendar = Calendar.getInstance(TimeZone.getTimeZone(zone))
        calendar.clear()
        calendar.set(parts[0], parts[1] - 1, parts[2], 12, 0)
        return CoupleDaysSpikeCalendar.count(start, calendar)
    }
    @Test fun calendarDaysIncludeFirstDayAndLeapDay() {
        assertEquals(1L, count("2026-11-01", "2026-11-01"))
        assertEquals(4L, count("2026-11-01", "2026-11-04"))
        assertEquals(3L, count("2024-02-28", "2024-03-01"))
        assertEquals(2L, count("2025-12-31", "2026-01-01"))
    }
    @Test fun daylightSavingAndDateLineDoNotUseElapsedHours() {
        assertEquals(3L, count("2026-03-07", "2026-03-09", "America/New_York"))
        assertEquals(3L, count("2026-10-31", "2026-11-02", "America/New_York"))
        assertEquals(1L, count("2026-11-02", "2026-11-01", "Pacific/Honolulu"))
    }
    @Test(expected = IllegalArgumentException::class) fun invalidDateIsRejected() {
        count("2026-02-30", "2026-03-01")
    }
}
