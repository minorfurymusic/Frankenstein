package br.com.frankstein.frankstein

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Ponte entre o Dart e [StepCounterService] — contador de passos real
 * (`.claude/rules/activity.md`). Dois canais:
 * - `MethodChannel` (`frankstein/steps`): start/stop do service, checar/
 *   pedir a permissão `ACTIVITY_RECOGNITION`, ler a leitura atual sob
 *   demanda (útil ao reabrir o app, sem esperar o próximo evento do
 *   sensor).
 * - `EventChannel` (`frankstein/steps/stream`): stream de leituras em
 *   tempo real enquanto o app está em primeiro plano — o app implementa
 *   `StepSensor` (`app/lib/step_sensor_android.dart`) sobre este canal.
 *
 * O service continua rodando com a Activity destruída — esta classe só
 * conversa com ele quando a Activity/engine Flutter está viva; não é
 * quem mantém a contagem funcionando com a tela bloqueada (isso é
 * responsabilidade do próprio `Service`, `startForeground` +
 * `START_STICKY`).
 */
class MainActivity : FlutterActivity() {
    private val methodChannelName = "frankstein/steps"
    private val eventChannelName = "frankstein/steps/stream"
    private val activityRecognitionRequestCode = 9001

    private var stepService: StepCounterService? = null
    private var bound = false
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as StepCounterService.LocalBinder
            stepService = binder.getService()
            bound = true
            attachListenerIfNeeded()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            stepService = null
            bound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSensor" -> result.success(stepService?.hasSensor() ?: false)
                    "hasActivityRecognitionPermission" -> result.success(hasActivityRecognitionPermission())
                    "requestActivityRecognitionPermission" -> requestActivityRecognitionPermission(result)
                    "startService" -> {
                        startStepService()
                        result.success(null)
                    }
                    "stopService" -> {
                        stopStepService()
                        result.success(null)
                    }
                    "getCurrentReading" -> {
                        val reading = stepService?.getCurrentReading()
                        result.success(
                            if (reading == null) null
                            else mapOf(
                                "cumulative_steps" to reading.cumulativeSteps,
                                "timestamp_utc_millis" to reading.timestampMillis,
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    attachListenerIfNeeded()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stepService?.setListener(null)
                }
            })
    }

    private fun attachListenerIfNeeded() {
        val sink = eventSink ?: return
        stepService?.setListener(StepCounterService.StepUpdateListener { reading ->
            runOnUiThread {
                sink.success(
                    mapOf(
                        "cumulative_steps" to reading.cumulativeSteps,
                        "timestamp_utc_millis" to reading.timestampMillis,
                    ),
                )
            }
        })
    }

    private fun hasActivityRecognitionPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACTIVITY_RECOGNITION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestActivityRecognitionPermission(result: MethodChannel.Result) {
        if (hasActivityRecognitionPermission()) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            activityRecognitionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != activityRecognitionRequestCode) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    private fun startStepService() {
        val intent = Intent(this, StepCounterService::class.java)
        ContextCompat.startForegroundService(this, intent)
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    private fun stopStepService() {
        if (bound) {
            stepService?.setListener(null)
            unbindService(serviceConnection)
            bound = false
        }
        stopService(Intent(this, StepCounterService::class.java))
    }

    override fun onDestroy() {
        if (bound) {
            unbindService(serviceConnection)
            bound = false
        }
        super.onDestroy()
    }
}
