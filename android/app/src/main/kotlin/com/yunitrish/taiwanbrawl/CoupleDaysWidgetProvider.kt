package com.yunitrish.taiwanbrawl

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

class CoupleDaysWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { refresh(context) }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) { refresh(context) }
    override fun onDisabled(context: Context) { alarm(context).cancel(tick(context)) }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in setOf(TICK, Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_LOCALE_CHANGED)) refresh(context)
    }
    companion object {
        const val OPEN = "com.yunitrish.taiwanbrawl.OPEN_COUPLE_WIDGET"
        private const val TICK = "com.yunitrish.taiwanbrawl.COUPLE_WIDGET_DAY"
        private fun alarm(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        private fun tick(context: Context) = PendingIntent.getBroadcast(context, 7108,
            Intent(context, CoupleDaysWidgetProvider::class.java).setAction(TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, CoupleDaysWidgetProvider::class.java))
            if (ids.isEmpty()) { alarm(context).cancel(tick(context)); return }
            val snapshot = try {
                context.getSharedPreferences("couple_widget_v1", Context.MODE_PRIVATE).getString("snapshot", null)?.let { raw ->
                    val json = JSONObject(raw)
                    json.keys().asSequence().associateWith { key -> if (json.isNull(key)) null else json.get(key) }
                }
            } catch (_: Exception) { null }
            val display = CoupleWidgetPresentation.read(snapshot, Calendar.getInstance())
            val palette = CoupleWidgetPalette.normalized(context.getSharedPreferences("couple_widget_v1", Context.MODE_PRIVATE).getString("palette", null))
            val text = when (display.status) {
                "active" -> context.getString(R.string.couple_widget_days, display.days)
                "unbound" -> context.getString(R.string.couple_widget_unbound)
                else -> context.getString(R.string.couple_widget_signed_out)
            }
            val open = PendingIntent.getActivity(context, 7109,
                Intent(context, MainActivity::class.java).setAction(OPEN)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.couple_days_widget)
                views.setInt(R.id.couple_widget_card, "setBackgroundResource", CoupleWidgetPalette.background(palette))
                views.setTextColor(R.id.couple_widget_text, CoupleWidgetPalette.ink(palette))
                views.setTextColor(R.id.couple_widget_partner, CoupleWidgetPalette.ink(palette))
                views.setTextViewText(R.id.couple_widget_partner, display.partnerName?.let { context.getString(R.string.couple_widget_partner_line, it) } ?: "")
                views.setViewVisibility(R.id.couple_widget_partner, if (display.partnerName != null) View.VISIBLE else View.GONE)
                val density = context.resources.displayMetrics.density
                views.setViewPadding(R.id.couple_widget_text, (16 * density).toInt(), ((if (display.partnerName != null) 30 else 16) * density).toInt(), (16 * density).toInt(), (12 * density).toInt())
                views.setTextColor(R.id.couple_widget_heart, CoupleWidgetPalette.ink(palette))
                views.setTextViewText(R.id.couple_widget_text, text)
                views.setContentDescription(R.id.couple_widget_text, display.partnerName?.let { context.getString(R.string.couple_widget_partner_line, it) + " " + text } ?: text)
                val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
                val height = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 60)
                views.setViewVisibility(R.id.couple_widget_heart, if (height >= 100 && width >= 140) View.VISIBLE else View.GONE)
                val fontScale = context.resources.configuration.fontScale.coerceAtLeast(1f)
                val size = ((width - 36).coerceAtLeast(40) / (text.length.coerceAtLeast(1) * 0.56f * fontScale)).coerceIn(12f, 36f)
                views.setTextViewTextSize(R.id.couple_widget_text, TypedValue.COMPLEX_UNIT_SP, size)
                views.setOnClickPendingIntent(R.id.couple_widget_text, open)
                views.setOnClickPendingIntent(R.id.couple_widget_card, open)
                manager.updateAppWidget(id, views)
            }
            val next = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            // Inexact, no exact-alarm/battery exemption. Periodic updates are fallback.
            alarm(context).set(AlarmManager.RTC, next.timeInMillis, tick(context))
        }
    }
}
