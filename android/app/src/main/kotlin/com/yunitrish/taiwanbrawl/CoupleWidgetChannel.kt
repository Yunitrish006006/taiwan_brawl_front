package com.yunitrish.taiwanbrawl

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Host-only writer; normal process, private preferences, one complete record. */
class CoupleWidgetChannel(context: Context, messenger: BinaryMessenger) {
    private val preferences = context.getSharedPreferences("couple_widget_v1", Context.MODE_PRIVATE)
    private val channel = MethodChannel(messenger, "taiwan_brawl/couple_widget")
    companion object { private val lock = Any() }
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                synchronized(lock) {
                    if (call.method == "readAppearance") {
                        result.success(CoupleWidgetPalette.normalized(preferences.getString("palette", null)))
                        return@setMethodCallHandler
                    }
                    if (call.method == "setAppearance") {
                        val palette = call.argument<String>("palette")
                        require(palette in CoupleWidgetPalette.ids)
                        check(preferences.edit().putString("palette", palette).commit())
                        try { CoupleDaysWidgetProvider.refresh(context) } catch (_: Exception) { }
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val raw = preferences.getString("snapshot", null)
                    val current = raw?.let { decode(JSONObject(it)) }
                    if (call.method == "readCounter") {
                        result.success(CoupleWidgetPresentation.counterProjection(current))
                        return@setMethodCallHandler
                    }
                    val next = when (call.method) {
                        "beginSession" -> CoupleWidgetState.begin(current, call.argument<String>("accountScope"))
                        "replace" -> {
                            require(current != null)
                            val snapshot = call.argument<Map<String, Any?>>("snapshot") ?: error("Missing snapshot")
                            CoupleWidgetState.replace(current, snapshot)
                        }
                        else -> { result.notImplemented(); return@setMethodCallHandler }
                    }
                    val json = JSONObject()
                    next.forEach { (key, value) -> json.put(key, value ?: JSONObject.NULL) }
                    check(preferences.edit().putString("snapshot", json.toString()).commit()) { "Persistence failed" }
                    // Persistence success is distinct from best-effort launcher redraw.
                    try { CoupleDaysWidgetProvider.refresh(context) } catch (_: Exception) { }
                    if (call.method == "beginSession") result.success(next["sessionGeneration"])
                    else result.success(null)
                }
            } catch (error: Exception) {
                result.error("WIDGET_WRITE_REJECTED", "Snapshot could not be persisted or was obsolete", null)
            }
        }
    }
    private fun decode(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key ->
        if (json.isNull(key)) null else json.get(key)
    }
}
