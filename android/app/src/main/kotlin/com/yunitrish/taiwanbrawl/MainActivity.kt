package com.yunitrish.taiwanbrawl

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private var widgetOpenPending = false
    private var widgetOpenChannel: MethodChannel? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        widgetOpenPending = if (savedInstanceState != null) savedInstanceState.getBoolean("coupleWidgetOpen") else intent?.action == CoupleDaysWidgetProvider.OPEN
        super.onCreate(savedInstanceState)
    }
    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("coupleWidgetOpen", widgetOpenPending)
        super.onSaveInstanceState(outState)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == CoupleDaysWidgetProvider.OPEN) {
            widgetOpenPending = true
            widgetOpenChannel?.invokeMethod("open", null)
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CoupleWidgetChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        widgetOpenChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "taiwan_brawl/couple_widget_open").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "consumeOpen") {
                    val pending = widgetOpenPending
                    widgetOpenPending = false
                    result.success(pending)
                } else result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "taiwan_brawl/device_time_zone")
            .setMethodCallHandler { call, result ->
                if (call.method == "current") result.success(TimeZone.getDefault().id)
                else result.notImplemented()
            }
    }
}
