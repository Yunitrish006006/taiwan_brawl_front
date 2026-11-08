package com.yunitrish.taiwanbrawl

import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

object CoupleDaysCalendar {
    fun count(startedOn: String, localToday: Calendar): Long {
        require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(startedOn))
        val parts = startedOn.split("-").map { it.toInt() }
        require(parts[0] >= 1900)
        fun day(year: Int, month: Int, date: Int): Long {
            val calendar = GregorianCalendar(TimeZone.getTimeZone("UTC"))
            calendar.clear(); calendar.isLenient = false
            calendar.set(year, month - 1, date)
            return calendar.timeInMillis / 86400000L
        }
        val start = day(parts[0], parts[1], parts[2])
        val today = day(localToday.get(Calendar.YEAR), localToday.get(Calendar.MONTH) + 1,
            localToday.get(Calendar.DAY_OF_MONTH))
        return maxOf(1, today - start + 1)
    }
}

data class CoupleWidgetDisplay(val status: String, val days: Long? = null, val partnerName: String? = null)
object CoupleWidgetPresentation {
    fun counterProjection(snapshot: Map<String, Any?>?): Map<String, Any?>? {
        if (read(snapshot, Calendar.getInstance()).status != "active") return null
        return mapOf("schemaVersion" to 1, "startedOn" to snapshot?.get("startedOn"), "lastSyncedAt" to snapshot?.get("lastSyncedAt"))
    }
    fun read(snapshot: Map<String, Any?>?, today: Calendar): CoupleWidgetDisplay {
        if (snapshot == null) return CoupleWidgetDisplay("signedOut")
        return try {
            require((snapshot["sessionGeneration"] as Number).toLong() > 0)
            val sequence = snapshot["requestSequence"]
            require(sequence is Int || sequence is Long)
            require((sequence as Number).toLong() >= 0)
            CoupleWidgetState.begin(null, snapshot["accountScope"] as String?)
            // Validate a stored empty reservation (sequence 0) as well as active records.
            CoupleWidgetState.replace(snapshot + ("requestSequence" to 0), snapshot + ("requestSequence" to 1))
            when (snapshot["status"]) {
                "active" -> CoupleWidgetDisplay("active", CoupleDaysCalendar.count(snapshot["startedOn"] as String, today), snapshot["partnerName"] as String?)
                "unbound" -> CoupleWidgetDisplay("unbound")
                else -> CoupleWidgetDisplay("signedOut")
            }
        } catch (_: Exception) { CoupleWidgetDisplay("signedOut") }
    }
}
