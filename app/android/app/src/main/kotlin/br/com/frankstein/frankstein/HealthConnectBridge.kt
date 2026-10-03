package br.com.frankstein.frankstein

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Leitura do Health Connect (ADR-4a, aceita: FEDERATE — o RLT só lê o que a
 * pulseira/relógio, ex. Gadgetbridge, escreveu no hub de saúde do Android).
 * Só **lê** sono e frequência cardíaca; nunca escreve. Tudo local: o Health
 * Connect não usa internet e nada sai do aparelho por aqui.
 *
 * Canal `rlt/health_connect`:
 * - `status` → "available" | "not_installed" | "update_required" | "unsupported"
 * - `grantedPermissions` → lista com "sleep" e/ou "heart_rate"
 * - `requestPermissions` → abre a tela do Health Connect; devolve as concedidas
 * - `readSleep` / `readHeartRate` (`from_millis`, `to_millis`) → registros
 * - `openSettings`, `openInstall`
 * - `consumeRationaleLaunch` → true se o app foi aberto pelo Health Connect
 *   para mostrar a política de privacidade.
 *
 * O Health Connect só existe do Android 9 (API 28) em diante; a biblioteca
 * pede API 26. O app continua instalando a partir da API 24
 * (`tools:overrideLibrary` no manifesto) e nada daqui roda abaixo da 28.
 */
object HealthConnectBridge {
    const val REQUEST_CODE = 9003
    private const val PROVIDER = "com.google.android.apps.healthdata"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var rationaleLaunch = false

    const val ACTION_RATIONALE = "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"
    const val ACTION_PERMISSION_USAGE = "android.intent.action.VIEW_PERMISSION_USAGE"

    fun noteLaunchIntent(intent: Intent?) {
        val action = intent?.action
        if (action == ACTION_RATIONALE || action == ACTION_PERMISSION_USAGE) rationaleLaunch = true
    }

    private fun supported() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status(activity))
            "consumeRationaleLaunch" -> {
                result.success(rationaleLaunch)
                rationaleLaunch = false
            }
            "openInstall" -> {
                val uri = Uri.parse("market://details?id=$PROVIDER&url=healthconnect%3A%2F%2Fonboarding")
                result.success(tryStart(activity, Intent(Intent.ACTION_VIEW, uri)))
            }
            "openSettings" -> result.success(
                tryStart(activity, Intent("android.health.connect.action.HEALTH_HOME_SETTINGS")) ||
                    tryStart(activity, Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")),
            )
            else -> {
                if (!supported() || status(activity) != "available") {
                    result.error("unavailable", "Health Connect indisponível", null)
                    return
                }
                Impl.handle(activity, call, result)
            }
        }
    }

    private fun tryStart(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    fun status(activity: Activity): String {
        if (!supported()) return "unsupported"
        return when (HealthConnectClient.getSdkStatus(activity, PROVIDER)) {
            HealthConnectClient.SDK_AVAILABLE -> "available"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
            else -> "not_installed"
        }
    }

    /** Volta da tela de permissões do Health Connect. */
    fun onActivityResult(activity: Activity, requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        if (!supported()) {
            result.success(emptyList<String>())
            return true
        }
        Impl.replyGranted(activity, result)
        return true
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private object Impl {
        private val sleepPermission = HealthPermission.getReadPermission(SleepSessionRecord::class)
        private val heartRatePermission = HealthPermission.getReadPermission(HeartRateRecord::class)
        private val all = setOf(sleepPermission, heartRatePermission)

        private fun keys(granted: Set<String>) = buildList {
            if (sleepPermission in granted) add("sleep")
            if (heartRatePermission in granted) add("heart_rate")
        }

        fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
            val client = HealthConnectClient.getOrCreate(activity)
            when (call.method) {
                "grantedPermissions" -> replyGranted(activity, result)
                "requestPermissions" -> {
                    pendingPermissionResult?.success(emptyList<String>())
                    pendingPermissionResult = result
                    val intent = PermissionController.createRequestPermissionResultContract().createIntent(activity, all)
                    try {
                        activity.startActivityForResult(intent, REQUEST_CODE)
                    } catch (e: ActivityNotFoundException) {
                        pendingPermissionResult = null
                        result.error("unavailable", e.message, null)
                    }
                }
                "readSleep" -> read(result) { readSleep(client, from(call), to(call)) }
                "readHeartRate" -> read(result) { readHeartRate(client, from(call), to(call)) }
                else -> result.notImplemented()
            }
        }

        fun replyGranted(activity: Activity, result: MethodChannel.Result) {
            scope.launch {
                try {
                    val granted = HealthConnectClient.getOrCreate(activity).permissionController.getGrantedPermissions()
                    result.success(keys(granted))
                } catch (e: Exception) {
                    result.error("health_connect", e.message, null)
                }
            }
        }

        private fun from(call: MethodCall) = Instant.ofEpochMilli((call.argument<Number>("from_millis"))!!.toLong())
        private fun to(call: MethodCall) = Instant.ofEpochMilli((call.argument<Number>("to_millis"))!!.toLong())

        private fun read(result: MethodChannel.Result, block: suspend () -> List<Map<String, Any>>) {
            scope.launch {
                try {
                    result.success(withContext(Dispatchers.IO) { block() })
                } catch (e: SecurityException) {
                    result.error("no_permission", e.message, null)
                } catch (e: Exception) {
                    result.error("health_connect", e.message, null)
                }
            }
        }

        private fun offsetMinutes(offset: ZoneOffset?, at: Instant): Int =
            (offset ?: ZoneId.systemDefault().rules.getOffset(at)).totalSeconds / 60

        // Valores fixos da API do Health Connect (SleepSessionRecord.STAGE_TYPE_*):
        // 1 acordado, 2 dormindo, 3 fora da cama, 4 leve, 5 profundo, 6 REM,
        // 7 acordado na cama.
        private fun stageName(stage: Int) = when (stage) {
            1, 3, 7 -> "awake"
            2 -> "sleeping"
            4 -> "light"
            5 -> "deep"
            6 -> "rem"
            else -> "unknown"
        }

        private suspend fun readSleep(client: HealthConnectClient, from: Instant, to: Instant): List<Map<String, Any>> {
            val out = mutableListOf<Map<String, Any>>()
            var token: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest(SleepSessionRecord::class, TimeRangeFilter.between(from, to), pageToken = token),
                )
                for (r in response.records) {
                    out.add(
                        mapOf(
                            "id" to r.metadata.id,
                            "start_millis" to r.startTime.toEpochMilli(),
                            "end_millis" to r.endTime.toEpochMilli(),
                            "tz_offset_minutes" to offsetMinutes(r.startZoneOffset, r.startTime),
                            "stages" to r.stages.map {
                                mapOf(
                                    "stage" to stageName(it.stage),
                                    "start_millis" to it.startTime.toEpochMilli(),
                                    "end_millis" to it.endTime.toEpochMilli(),
                                )
                            },
                        ),
                    )
                }
                token = response.pageToken
            } while (token != null)
            return out
        }

        private suspend fun readHeartRate(client: HealthConnectClient, from: Instant, to: Instant): List<Map<String, Any>> {
            val out = mutableListOf<Map<String, Any>>()
            var token: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest(HeartRateRecord::class, TimeRangeFilter.between(from, to), pageToken = token),
                )
                for (r in response.records) {
                    r.samples.forEachIndexed { i, s ->
                        out.add(
                            mapOf(
                                "id" to "${r.metadata.id}#$i",
                                "time_millis" to s.time.toEpochMilli(),
                                "bpm" to s.beatsPerMinute,
                                "tz_offset_minutes" to offsetMinutes(r.startZoneOffset, s.time),
                            ),
                        )
                    }
                }
                token = response.pageToken
            } while (token != null)
            return out
        }
    }
}
