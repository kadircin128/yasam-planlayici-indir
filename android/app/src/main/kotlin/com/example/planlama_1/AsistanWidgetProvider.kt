package com.example.planlama_1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AsistanWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.asistan_widget_layout).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val bakiye = widgetData.getString("net_bakiye", "0 ₺") ?: "0 ₺"
                val etkinlik = widgetData.getString("siradaki_etkinlik", "Bugün bekleyen plan yok")
                    ?: "Bugün bekleyen plan yok"
                val gorev = widgetData.getString("kalan_gorev", "0 Görev") ?: "0 Görev"
                val saat = widgetData.getString("son_guncelleme", "") ?: ""

                setTextViewText(R.id.tv_bakiye, bakiye)
                setTextViewText(R.id.tv_etkinlik, "📅 $etkinlik")
                setTextViewText(R.id.tv_gorev, gorev)
                setTextViewText(R.id.tv_saat, saat)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}