package br.com.frankstein.frankstein

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Canal `rlt/voice`: voz no Cérebro (prancheta CerebroEntradas, "Segurar
 * para gravar voz"). Grava com o `MediaRecorder` do próprio Android em AAC
 * (ADTS, `audio/aac` — formato aceito pelo Gemini), mono, 16 kHz, num
 * arquivo temporário do cache do app; `stop` devolve os bytes e apaga o
 * arquivo. Nada fica guardado e nada sai do celular por aqui — quem envia
 * é o app, depois do consentimento (ADR-11).
 *
 * Métodos: `hasPermission`, `requestPermission`, `start`, `stop`
 * (→ `{bytes, duration_ms}` ou null), `cancel`.
 */
object VoiceBridge {
    const val REQUEST_CODE = 9007
    private var pendingPermission: MethodChannel.Result? = null
    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var startedAt = 0L

    private fun hasPermission(activity: Activity) =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission(activity))
            "requestPermission" -> {
                if (hasPermission(activity)) {
                    result.success(true)
                    return
                }
                pendingPermission?.success(false)
                pendingPermission = result
                ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_CODE)
            }
            "start" -> {
                if (!hasPermission(activity)) {
                    result.error("no_permission", "sem permissão de microfone", null)
                    return
                }
                release()
                try {
                    val out = File.createTempFile("voz", ".aac", activity.cacheDir)
                    @Suppress("DEPRECATION")
                    val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(activity) else MediaRecorder()
                    r.setAudioSource(MediaRecorder.AudioSource.MIC)
                    r.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
                    r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                    r.setAudioChannels(1)
                    r.setAudioSamplingRate(16000)
                    r.setAudioEncodingBitRate(32000)
                    r.setOutputFile(out.absolutePath)
                    r.prepare()
                    r.start()
                    recorder = r
                    file = out
                    startedAt = SystemClock.elapsedRealtime()
                    result.success(true)
                } catch (e: Exception) {
                    release()
                    result.error("record_failed", e.message, null)
                }
            }
            "stop" -> {
                val r = recorder
                val f = file
                if (r == null || f == null) {
                    result.success(null)
                    return
                }
                val duration = SystemClock.elapsedRealtime() - startedAt
                val ok = try {
                    r.stop()
                    true
                } catch (e: RuntimeException) {
                    // Gravação curta demais: o MediaRecorder não tem o que fechar.
                    false
                }
                recorder = null
                r.release()
                val bytes = if (ok && f.exists()) f.readBytes() else null
                f.delete()
                file = null
                result.success(if (bytes == null || bytes.isEmpty()) null else mapOf("bytes" to bytes, "duration_ms" to duration))
            }
            "cancel" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun release() {
        try {
            recorder?.stop()
        } catch (_: RuntimeException) {
        }
        recorder?.release()
        recorder = null
        file?.delete()
        file = null
    }

    fun onPermissionResult(activity: Activity, requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.success(hasPermission(activity))
        pendingPermission = null
        return true
    }
}
