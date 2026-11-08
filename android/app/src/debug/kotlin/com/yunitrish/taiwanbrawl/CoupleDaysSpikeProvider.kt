package com.yunitrish.taiwanbrawl

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.TimeZone

/** Debug-only fixture, deliberately disconnected from real accounts and credentials. */
class CoupleDaysSpikeProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = RemoteViews(context.packageName, R.layout.couple_days_spike)
        val days = CoupleDaysSpikeCalendar.count("2026-11-01", Calendar.getInstance())
        views.setTextViewText(R.id.couple_days_spike_text, context.getString(R.string.couple_days_spike_count, days))
        val open = Intent(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.couple_days_spike_text,
            PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        manager.updateAppWidget(ids, views)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in setOf(Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_LOCALE_CHANGED)) {
            val manager = AppWidgetManager.getInstance(context)
            onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, javaClass)))
        }
    }
}

/** Compare calendar dates in UTC after reading today's local date; DST is not a day. */
object CoupleDaysSpikeCalendar {
    fun count(startedOn: String, localToday: Calendar): Long {
        require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(startedOn))
        val parts = startedOn.split("-").map { it.toInt() }
        require(parts[0] >= 1900)
        fun day(year: Int, month: Int, date: Int): Long {
            val calendar = GregorianCalendar(TimeZone.getTimeZone("UTC"))
            calendar.clear()
            calendar.isLenient = false
            calendar.set(year, month - 1, date)
            return calendar.timeInMillis / 86400000L
        }
        val start = day(parts[0], parts[1], parts[2])
        val today = day(localToday.get(Calendar.YEAR), localToday.get(Calendar.MONTH) + 1,
            localToday.get(Calendar.DAY_OF_MONTH))
        return maxOf(1, today - start + 1)
    }
}
