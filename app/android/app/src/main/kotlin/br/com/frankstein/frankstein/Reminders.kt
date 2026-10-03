package br.com.frankstein.frankstein

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Lembretes locais do RLT (remédio, água, treino) — só o AlarmManager e as
 * notificações do próprio Android, sem Firebase nem biblioteca de terceiros
 * (`.claude/rules/licenca.md`, ADR-10 "notificações locais"). Nada sai do
 * aparelho.
 *
 * O Dart planeja os próximos dias e manda a lista inteira ([sync]); aqui
 * cada item vira um alarme `setAndAllowWhileIdle` (dispara mesmo em modo
 * soneca, com tolerância de alguns minutos — não exige a permissão de
 * alarme exato). A lista fica guardada para ser reagendada depois de
 * reiniciar o celular ([ReminderBootReceiver]).
 */
object Reminders {
    const val CHANNEL_ID = "rlt_lembretes"
    private const val PREFS = "rlt_reminders"
    private const val KEY = "scheduled"

    data class Item(val id: Int, val atMillis: Long, val title: String, val body: String) {
        fun toJson(): JSONObject = JSONObject()
            .put("id", id)
            .put("at", atMillis)
            .put("title", title)
            .put("body", body)

        companion object {
            fun fromJson(o: JSONObject) = Item(o.getInt("id"), o.getLong("at"), o.getString("title"), o.getString("body"))
        }
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Lembretes", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Remédios, água e treino"
            },
        )
    }

    /** Substitui todos os lembretes agendados por [items]. */
    fun sync(context: Context, items: List<Item>) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (old in load(context)) {
            alarms.cancel(pendingIntent(context, old))
        }
        val now = System.currentTimeMillis()
        val future = items.filter { it.atMillis > now }
        save(context, future)
        for (item in future) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, item.atMillis, pendingIntent(context, item))
        }
    }

    fun rescheduleStored(context: Context) = sync(context, load(context))

    fun load(context: Context): List<Item> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        val array = JSONArray(raw)
        return (0 until array.length()).map { Item.fromJson(array.getJSONObject(it)) }
    }

    private fun save(context: Context, items: List<Item>) {
        val array = JSONArray()
        items.forEach { array.put(it.toJson()) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, array.toString()).apply()
    }

    private fun pendingIntent(context: Context, item: Item): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
            .putExtra("id", item.id)
            .putExtra("title", item.title)
            .putExtra("body", item.body)
        return PendingIntent.getBroadcast(
            context,
            item.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/** Mostra a notificação quando o alarme dispara. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.ensureChannel(context)
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, Reminders.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(intent.getStringExtra("title") ?: "RLT")
            .setContentText(intent.getStringExtra("body") ?: "")
            .setStyle(NotificationCompat.BigTextStyle().bigText(intent.getStringExtra("body") ?: ""))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        val manager = NotificationManagerCompat.from(context)
        if (manager.areNotificationsEnabled()) {
            try {
                manager.notify(intent.getIntExtra("id", 0), notification)
            } catch (_: SecurityException) {
                // Permissão de notificação revogada entre o agendamento e o disparo.
            }
        }
    }
}

/** Reagenda depois de reiniciar o celular ou atualizar o app. */
class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> Reminders.rescheduleStored(context)
        }
    }
}
