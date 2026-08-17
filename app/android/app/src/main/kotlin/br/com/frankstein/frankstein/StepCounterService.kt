package br.com.frankstein.frankstein

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Binder
import android.os.Build
import android.os.IBinder

/**
 * Foreground service do contador de passos real
 * (`.claude/rules/activity.md`: "Foreground service no Android. A
 * contagem NÃO pode parar com a tela bloqueada. Esse é o bug que matou o
 * projeto anterior: trate como requisito, não como detalhe.").
 *
 * Ouve `TYPE_STEP_COUNTER` (contador cumulativo desde o último boot,
 * mesma semântica documentada em
 * `packages/activity/lib/src/steps_sample.dart:3-7`) e guarda a última
 * leitura em memória — `MainActivity` se conecta via [LocalBinder] pra
 * consultar a leitura atual (`getCurrentReading`) e registrar um
 * [StepUpdateListener] pra receber cada leitura nova em tempo real,
 * repassada ao Dart pelo `EventChannel` (`MainActivity.kt`).
 *
 * Continua rodando com a Activity destruída/tela bloqueada — é
 * exatamente esse o motivo de existir como `Service` com
 * `startForeground`, não como listener preso ao ciclo de vida da
 * Activity.
 */
class StepCounterService : Service(), SensorEventListener {

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "frankstein_step_counter"
        private const val NOTIFICATION_ID = 1001
    }

    /** Uma leitura crua do sensor — espelha `StepsSample` do lado Dart. */
    data class StepReading(val cumulativeSteps: Int, val timestampMillis: Long)

    fun interface StepUpdateListener {
        fun onStepUpdate(reading: StepReading)
    }

    inner class LocalBinder : Binder() {
        fun getService(): StepCounterService = this@StepCounterService
    }

    private val binder = LocalBinder()
    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null
    private var lastReading: StepReading? = null
    private var listener: StepUpdateListener? = null

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        val sensor = stepCounterSensor
        if (sensor != null) {
            sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
        // START_STICKY: se o sistema matar o processo pra liberar memória,
        // o Android recria o service (sem o Intent original) assim que
        // possível — parte do requisito de "não pode parar com a tela
        // bloqueada".
        return START_STICKY
    }

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        val reading = StepReading(
            cumulativeSteps = event.values[0].toInt(),
            timestampMillis = System.currentTimeMillis(),
        )
        lastReading = reading
        listener?.onStepUpdate(reading)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Sem uso — TYPE_STEP_COUNTER não tem noção de "acurácia" relevante
        // (ao contrário de sensores de posição/GPS, que já têm o próprio
        // filtro em `.claude/rules/activity.md`, corrida/caminhada).
    }

    fun hasSensor(): Boolean = stepCounterSensor != null

    fun getCurrentReading(): StepReading? = lastReading

    fun setListener(newListener: StepUpdateListener?) {
        listener = newListener
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Contador de passos",
                NotificationManager.IMPORTANCE_MIN,
            )
            channel.description = "Mantém a contagem de passos ativa com a tela bloqueada"
            manager.createNotificationChannel(channel)
        }

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = if (openAppIntent != null) {
            PendingIntent.getActivity(
                this,
                0,
                openAppIntent,
                PendingIntent.FLAG_IMMUTABLE,
            )
        } else null

        return Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Frankstein")
            .setContentText("Contando seus passos")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()
    }
}
