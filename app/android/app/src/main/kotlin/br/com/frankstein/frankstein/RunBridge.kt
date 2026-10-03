package br.com.frankstein.frankstein

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Canal `rlt/run` entre o app e o [RunRecorderService]:
 * `hasPermission`, `requestPermission` (localização precisa, só enquanto o
 * app está em uso — não pede localização em segundo plano), `gpsEnabled`,
 * `start` (`kind`, `auto_pause`), `pause`, `resume`, `finish`, `status`,
 * `points` (`from`), `discard`.
 */
object RunBridge {
    const val REQUEST_CODE = 9004
    private var pendingPermission: MethodChannel.Result? = null

    private fun hasPermission(activity: Activity) =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        val service = RunRecorderService.instance
        when (call.method) {
            "hasPermission" -> result.success(hasPermission(activity))
            "requestPermission" -> {
                if (hasPermission(activity)) {
                    result.success(true)
                    return
                }
                pendingPermission?.success(false)
                pendingPermission = result
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                    REQUEST_CODE,
                )
            }
            "gpsEnabled" -> {
                val lm = activity.getSystemService(Activity.LOCATION_SERVICE) as LocationManager
                result.success(lm.isProviderEnabled(LocationManager.GPS_PROVIDER))
            }
            "start" -> {
                if (!hasPermission(activity)) {
                    result.error("no_permission", "sem permissão de localização", null)
                    return
                }
                val intent = Intent(activity, RunRecorderService::class.java)
                    .putExtra(RunRecorderService.EXTRA_KIND, call.argument<String>("kind") ?: "run")
                    .putExtra(RunRecorderService.EXTRA_AUTO_PAUSE, call.argument<Boolean>("auto_pause") ?: true)
                ContextCompat.startForegroundService(activity, intent)
                result.success(true)
            }
            "pause" -> {
                service?.pause()
                result.success(service != null)
            }
            "resume" -> {
                service?.resume()
                result.success(service != null)
            }
            "finish" -> {
                service?.finish()
                result.success(true)
            }
            "status" -> result.success(status(activity, service))
            "points" -> {
                val from = call.argument<Int>("from") ?: 0
                val list = service?.pointsFrom(from) ?: RunRecorderService.readFile(activity).second.drop(from)
                result.success(list.map(::toMap))
            }
            "discard" -> {
                if (service == null) RunRecorderService.file(activity).delete()
                result.success(service == null)
            }
            else -> result.notImplemented()
        }
    }

    private fun status(activity: Activity, service: RunRecorderService?): Map<String, Any?> {
        if (service != null) {
            return mapOf(
                "state" to service.state,
                "kind" to service.kind,
                "active_ms" to service.activeMs(),
                "points" to service.pointCount(),
                "last_accuracy" to service.lastAccuracy?.toDouble(),
                "last_fix_age_ms" to service.lastFixAgeMs(),
            )
        }
        val (header, points) = RunRecorderService.readFile(activity)
        if (header == null && points.isEmpty()) return mapOf("state" to "idle")
        return mapOf(
            "state" to "interrupted",
            "kind" to (header?.optString("kind", "run") ?: "run"),
            "points" to points.size,
        )
    }

    private fun toMap(o: JSONObject): Map<String, Any?> = mapOf(
        "lat" to o.getDouble("lat"),
        "lon" to o.getDouble("lon"),
        "t" to o.getLong("t"),
        "seg" to o.optInt("seg"),
        "alt" to (if (o.has("alt")) o.getDouble("alt") else null),
        "acc" to (if (o.has("acc")) o.getDouble("acc") else null),
    )

    fun onPermissionResult(activity: Activity, requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.success(hasPermission(activity))
        pendingPermission = null
        return true
    }
}
