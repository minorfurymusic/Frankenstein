package br.com.frankstein.frankstein

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.json.JSONObject
import java.io.File

/**
 * Gravador próprio de corrida/caminhada (ADR-9, revisão 1): serviço em
 * primeiro plano com o `LocationManager` do próprio Android (provedor GPS)
 * — sem Google Play Services, sem código de terceiros.
 *
 * - Cada ponto vai na hora para `run_current.jsonl` (pasta privada do app):
 *   se o app ou o processo morrer, nada se perde; o Android recria o serviço
 *   (START_STICKY), que continua num trecho novo.
 * - Pausa manual e pausa automática (parado por ~8 s com sinal bom) abrem um
 *   trecho novo: o caminho feito pausado não conta.
 * - Grava todos os pontos com a precisão relatada; quem descarta pior que
 *   20 m e filtra ruído é o Dart (`RunCalculator`), na hora de salvar.
 * - Nada sai do aparelho.
 */
class RunRecorderService : Service(), LocationListener {
    companion object {
        const val CHANNEL_ID = "rlt_corrida"
        const val NOTIFICATION_ID = 4102
        const val EXTRA_KIND = "kind"
        const val EXTRA_AUTO_PAUSE = "auto_pause"
        private const val FILE_NAME = "run_current.jsonl"
        private const val AUTO_PAUSE_AFTER_MS = 8_000L
        private const val STILL_SPEED = 0.5f // m/s
        private const val MOVING_SPEED = 1.0f // m/s
        private const val GOOD_ACCURACY = 20f // m

        @Volatile
        var instance: RunRecorderService? = null
            private set

        fun file(context: Context) = File(context.filesDir, FILE_NAME)

        /** Lê o que está gravado no arquivo (serviço vivo ou interrompido). */
        fun readFile(context: Context): Pair<JSONObject?, List<JSONObject>> {
            val f = file(context)
            if (!f.exists()) return null to emptyList()
            var header: JSONObject? = null
            val points = mutableListOf<JSONObject>()
            f.forEachLine { line ->
                if (line.isBlank()) return@forEachLine
                try {
                    val o = JSONObject(line)
                    if (o.optString("type") == "header") header = o else points.add(o)
                } catch (e: Exception) {
                    // Linha cortada no meio por queda do processo: ignora só ela.
                }
            }
            return header to points
        }
    }

    var state = "recording"
        private set
    var kind = "run"
        private set
    private var autoPause = true
    private var segment = 0
    private val points = mutableListOf<JSONObject>()
    private var activeAccumMs = 0L
    private var activeSince: Long? = null
    private var stillSince: Long? = null
    private var lastGood: Location? = null
    var lastAccuracy: Float? = null
        private set
    private var lastFixElapsed: Long? = null
    private var locationManager: LocationManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val (header, saved) = readFile(this)
        if (intent?.hasExtra(EXTRA_KIND) == true && saved.isEmpty()) {
            kind = intent.getStringExtra(EXTRA_KIND) ?: "run"
            autoPause = intent.getBooleanExtra(EXTRA_AUTO_PAUSE, true)
            file(this).writeText(
                JSONObject()
                    .put("type", "header")
                    .put("kind", kind)
                    .put("auto_pause", autoPause)
                    .put("started_at", System.currentTimeMillis())
                    .toString() + "\n",
            )
        } else {
            // Recriado pelo Android depois de o processo morrer: continua de
            // onde parou, num trecho novo.
            kind = header?.optString("kind", "run") ?: "run"
            autoPause = header?.optBoolean("auto_pause", true) ?: true
            points.clear()
            points.addAll(saved)
            segment = (saved.maxOfOrNull { it.optInt("seg") } ?: -1) + 1
        }
        state = "recording"
        activeSince = SystemClock.elapsedRealtime()
        startInForeground()
        try {
            locationManager?.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, this, Looper.getMainLooper())
        } catch (e: SecurityException) {
            state = "no_permission"
        } catch (e: IllegalArgumentException) {
            state = "no_gps"
        }
        return START_STICKY
    }

    override fun onDestroy() {
        locationManager?.removeUpdates(this)
        instance = null
        super.onDestroy()
    }

    // ---- comandos do app ----

    fun pause() {
        if (state != "recording" && state != "auto_paused") return
        stopActiveClock()
        state = "paused"
    }

    fun resume() {
        if (state != "paused" && state != "auto_paused") return
        segment++
        state = "recording"
        stillSince = null
        activeSince = SystemClock.elapsedRealtime()
    }

    fun finish() {
        stopActiveClock()
        state = "finished"
        locationManager?.removeUpdates(this)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    fun activeMs(): Long = activeAccumMs + (activeSince?.let { SystemClock.elapsedRealtime() - it } ?: 0L)

    fun lastFixAgeMs(): Long? = lastFixElapsed?.let { SystemClock.elapsedRealtime() - it }

    fun pointsFrom(index: Int): List<JSONObject> = if (index >= points.size) emptyList() else points.subList(index, points.size).toList()

    fun pointCount() = points.size

    private fun stopActiveClock() {
        activeSince?.let { activeAccumMs += SystemClock.elapsedRealtime() - it }
        activeSince = null
    }

    // ---- GPS ----

    override fun onLocationChanged(location: Location) {
        lastFixElapsed = SystemClock.elapsedRealtime()
        lastAccuracy = if (location.hasAccuracy()) location.accuracy else null
        val good = location.hasAccuracy() && location.accuracy <= GOOD_ACCURACY
        if (autoPause && good) handleAutoPause(location)
        if (state != "recording") return
        val o = JSONObject()
            .put("lat", location.latitude)
            .put("lon", location.longitude)
            .put("t", location.time)
            .put("seg", segment)
        if (location.hasAltitude()) o.put("alt", location.altitude)
        if (location.hasAccuracy()) o.put("acc", location.accuracy.toDouble())
        points.add(o)
        try {
            file(this).appendText(o.toString() + "\n")
        } catch (e: Exception) {
            // Sem espaço em disco: o ponto fica só na memória; o app avisa no fim.
        }
        if (good) lastGood = location
    }

    private fun handleAutoPause(location: Location) {
        val prev = lastGood
        val speed = when {
            location.hasSpeed() -> location.speed
            prev != null && location.time > prev.time -> prev.distanceTo(location) / ((location.time - prev.time) / 1000f)
            else -> null
        } ?: return
        val now = SystemClock.elapsedRealtime()
        if (state == "recording") {
            if (speed < STILL_SPEED) {
                val since = stillSince ?: now.also { stillSince = it }
                if (now - since >= AUTO_PAUSE_AFTER_MS) {
                    stopActiveClock()
                    state = "auto_paused"
                }
            } else {
                stillSince = null
            }
        } else if (state == "auto_paused" && speed > MOVING_SPEED) {
            resume()
            lastGood = location
        }
    }

    @Deprecated("Exigido em APIs antigas")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}

    // ---- notificação ----

    private fun startInForeground() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Corrida e caminhada", NotificationManager.IMPORTANCE_LOW)
            channel.description = "Mantém a gravação da rota com a tela bloqueada"
            manager.createNotificationChannel(channel)
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 2, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RLT")
            .setContentText(if (kind == "walk") "Gravando sua caminhada" else "Gravando sua corrida")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(open)
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }
}
