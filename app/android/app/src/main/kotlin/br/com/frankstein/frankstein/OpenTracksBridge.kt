package br.com.frankstein.frankstein

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Integração com o app OpenTracks instalado (ADR-9, revisão 2) — só pelas
 * APIs públicas dele, sem copiar código (Apache-2.0 do lado de lá, nada
 * embutido aqui). Fonte: README.md, README_API.md e
 * `IntentDashboardUtils.java`/`publicapi/StartRecording.java` do repositório
 * OpenTracksApp/OpenTracks.
 *
 * - **API pública** (desligada por padrão no OpenTracks): `StartRecording` e
 *   `StopRecording` por Intent explícita. Com `STATS_TARGET_PACKAGE/CLASS`,
 *   o OpenTracks devolve a trilha em gravação para o RLT.
 * - **API de dados** (também desligada por padrão): Intent
 *   `Intent.OpenTracks-Dashboard` com URIs de leitura temporária da trilha e
 *   dos pontos. Chega na [MainActivity] — quando o RLT inicia a gravação, ou
 *   quando a pessoa escolhe "mostrar no painel" no OpenTracks.
 *
 * Canal `rlt/opentracks`: `installed`, `start` (`kind`), `stop`, `session`,
 * `read`, `clear`.
 */
object OpenTracksBridge {
    private val packages = listOf(
        "de.dennisguse.opentracks",
        "de.dennisguse.opentracks.playStore",
        "de.dennisguse.opentracks.playstore",
        "de.dennisguse.opentracks.nightly",
        "de.dennisguse.opentracks.debug",
    )
    private const val ACTION_DASHBOARD = "Intent.OpenTracks-Dashboard"
    private const val EXTRA_PAYLOAD = "$ACTION_DASHBOARD.Payload"
    private const val EXTRA_IS_RECORDING = "EXTRAS_OPENTRACKS_IS_RECORDING_THIS_TRACK"

    private class Session(val trackUri: Uri, val pointsUri: Uri, val recording: Boolean, val receivedAt: Long)

    private var session: Session? = null

    /** Chamado pela MainActivity em onCreate/onNewIntent. */
    fun noteIntent(intent: Intent?) {
        if (intent?.action != ACTION_DASHBOARD) return
        @Suppress("DEPRECATION")
        val uris: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(EXTRA_PAYLOAD, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(EXTRA_PAYLOAD)
        }
        if (uris == null || uris.size < 2) return
        session = Session(uris[0], uris[1], intent.getBooleanExtra(EXTRA_IS_RECORDING, false), System.currentTimeMillis())
    }

    private fun installedPackage(activity: Activity): String? = packages.firstOrNull {
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                activity.packageManager.getPackageInfo(it, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                activity.packageManager.getPackageInfo(it, 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installed" -> result.success(installedPackage(activity) != null)
            "start" -> {
                val pkg = installedPackage(activity) ?: return result.error("not_installed", null, null)
                val kind = call.argument<String>("kind") ?: "run"
                session = null
                val intent = Intent()
                    .setClassName(pkg, "de.dennisguse.opentracks.publicapi.StartRecording")
                    .putExtra("TRACK_NAME", if (kind == "walk") "Caminhada (RLT)" else "Corrida (RLT)")
                    .putExtra("TRACK_ICON", if (kind == "walk") "walking" else "running")
                    .putExtra("STATS_TARGET_PACKAGE", activity.packageName)
                    .putExtra("STATS_TARGET_CLASS", MainActivity::class.java.name)
                result.success(tryStart(activity, intent))
            }
            "stop" -> {
                val pkg = installedPackage(activity) ?: return result.error("not_installed", null, null)
                result.success(tryStart(activity, Intent().setClassName(pkg, "de.dennisguse.opentracks.publicapi.StopRecording")))
            }
            "session" -> result.success(
                session?.let { mapOf("recording" to it.recording, "received_at" to it.receivedAt) },
            )
            "read" -> {
                val s = session ?: return result.success(null)
                try {
                    result.success(read(activity, s))
                } catch (e: SecurityException) {
                    // A permissão temporária do OpenTracks acabou.
                    session = null
                    result.error("expired", e.message, null)
                } catch (e: Exception) {
                    result.error("unreadable", e.message, null)
                }
            }
            "clear" -> {
                session = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun tryStart(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (e: ActivityNotFoundException) {
        false
    } catch (e: SecurityException) {
        false
    }

    private fun read(activity: Activity, s: Session): List<Map<String, Any?>> {
        val resolver = activity.contentResolver
        val tracks = linkedMapOf<Long, MutableMap<String, Any?>>()
        resolver.query(s.trackUri, null, null, null, null)?.use { c ->
            val id = c.getColumnIndex("_id")
            val name = c.getColumnIndex("name")
            val type = c.getColumnIndex("activity_type")
            val uuid = c.getColumnIndex("uuid")
            val offset = c.getColumnIndex("starttime_offset")
            while (c.moveToNext()) {
                val trackId = c.getLong(id)
                tracks[trackId] = mutableMapOf(
                    "id" to trackId,
                    "name" to (if (name >= 0) c.getString(name) else null),
                    "activity_type" to (if (type >= 0) c.getString(type) else null),
                    "uuid" to (if (uuid >= 0 && !c.isNull(uuid)) c.getBlob(uuid).joinToString("") { b -> "%02x".format(b) } else null),
                    "tz_offset_seconds" to (if (offset >= 0 && !c.isNull(offset)) c.getInt(offset) else null),
                    "recording" to s.recording,
                    "points" to mutableListOf<Map<String, Any?>>(),
                )
            }
        }
        resolver.query(s.pointsUri, null, null, null, null)?.use { c ->
            val trackId = c.getColumnIndex("trackid")
            val lat = c.getColumnIndex("latitude")
            val lon = c.getColumnIndex("longitude")
            val time = c.getColumnIndex("time")
            val ele = c.getColumnIndex("elevation")
            val acc = c.getColumnIndex("accuracy")
            val type = c.getColumnIndex("type")
            while (c.moveToNext()) {
                val t = tracks[c.getLong(trackId)] ?: continue
                @Suppress("UNCHECKED_CAST")
                (t["points"] as MutableList<Map<String, Any?>>).add(
                    mapOf(
                        // Latitude/longitude gravadas ×1E6 como inteiro no OpenTracks.
                        "lat" to (if (c.isNull(lat)) null else c.getInt(lat) / 1E6),
                        "lon" to (if (c.isNull(lon)) null else c.getInt(lon) / 1E6),
                        "t" to c.getLong(time),
                        "alt" to (if (ele >= 0 && !c.isNull(ele)) c.getDouble(ele) else null),
                        "acc" to (if (acc >= 0 && !c.isNull(acc)) c.getDouble(acc) else null),
                        "type" to (if (type >= 0 && !c.isNull(type)) c.getString(type).toIntOrNull() ?: 0 else 0),
                    ),
                )
            }
        }
        return tracks.values.toList()
    }
}
