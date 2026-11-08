package com.yunitrish.taiwanbrawl

import java.util.GregorianCalendar
import java.util.TimeZone

/** Pure state machine. Native persistence commits the returned whole record. */
object CoupleWidgetState {
    private val fields = setOf("schemaVersion", "accountScope", "sessionGeneration", "requestSequence",
        "relationshipId", "relationshipVersion", "startedOn", "status", "lastSyncedAt")
    private fun integer(value: Any?): Long {
        require(value is Int || value is Long)
        return (value as Number).toLong().also { require(it in 0..9007199254740991L) }
    }
    fun begin(previous: Map<String, Any?>?, scope: String?): Map<String, Any?> {
        require(scope == null || Regex("[a-f0-9]{64}").matches(scope))
        val generation = integer(previous?.get("sessionGeneration") ?: 0) + 1
        require(generation <= 9007199254740991L)
        return mapOf("schemaVersion" to 1, "accountScope" to scope, "sessionGeneration" to generation,
            "requestSequence" to 0, "relationshipId" to null, "relationshipVersion" to null,
            "startedOn" to null, "status" to if (scope == null) "signedOut" else "unbound", "lastSyncedAt" to null)
    }
    fun replace(current: Map<String, Any?>, next: Map<String, Any?>): Map<String, Any?> {
        require((next.keys == fields || next.keys == fields + "partnerName") && integer(next["schemaVersion"]) == 1L)
        require(integer(next["sessionGeneration"]) == integer(current["sessionGeneration"]))
        require(next["accountScope"] == current["accountScope"])
        require(integer(next["requestSequence"]) > integer(current["requestSequence"]))
        val status = next["status"]
        require(status in setOf("active", "unbound", "signedOut"))
        require((next["accountScope"] == null) == (status == "signedOut"))
        if (status == "active") {
            val name = next["partnerName"]
            require(name == null || (name is String && name.isNotBlank() && name.length <= 160 && name.none { it.isISOControl() }))
            require((next["relationshipId"] as? String)?.isNotBlank() == true)
            require(integer(next["relationshipVersion"]) >= 1)
            val date = next["startedOn"] as? String ?: error("Missing date")
            require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(date))
            val parts = date.split("-").map { it.toInt() }
            require(parts[0] >= 1900)
            val calendar = GregorianCalendar(TimeZone.getTimeZone("UTC"))
            calendar.clear(); calendar.isLenient = false
            calendar.set(parts[0], parts[1] - 1, parts[2]); calendar.timeInMillis
            require((next["lastSyncedAt"] as? String)?.matches(Regex("\\d{4}-\\d{2}-\\d{2}T.*Z")) == true)
        } else {
            require(listOf("relationshipId", "relationshipVersion", "startedOn", "lastSyncedAt", "partnerName").all { next[it] == null })
        }
        return next.toMap()
    }
}
