package br.com.frankstein.frankstein

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Cofre da chave da IA (ADR-11, `.claude/rules/brain.md`: "chave em
 * armazenamento seguro do Android"). Chave AES-256 gerada dentro do Android
 * Keystore (não sai do aparelho, não é exportável); o texto cifrado (AES-GCM)
 * fica num SharedPreferences privado. Backup do app desligado no manifesto.
 * Sem biblioteca nova. Canal `rlt/secure`: `get`, `set`, `delete` (`name`,
 * `value`). Nunca registra o valor em log.
 */
object SecureStore {
    private const val KEY_ALIAS = "rlt_secure_key"
    private const val PREFS = "rlt_secure"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        if (name.isNullOrBlank()) {
            result.error("bad_args", "name ausente", null)
            return
        }
        try {
            when (call.method) {
                "get" -> result.success(get(context, name))
                "set" -> {
                    set(context, name, call.argument<String>("value") ?: "")
                    result.success(true)
                }
                "delete" -> {
                    prefs(context).edit().remove(name).apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // Mensagem sem o valor guardado.
            result.error("secure_store", e.javaClass.simpleName, null)
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (ks.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        gen.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return gen.generateKey()
    }

    private fun set(context: Context, name: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val packed = cipher.iv + encrypted
        prefs(context).edit().putString(name, Base64.encodeToString(packed, Base64.NO_WRAP)).apply()
    }

    private fun get(context: Context, name: String): String? {
        val stored = prefs(context).getString(name, null) ?: return null
        val packed = Base64.decode(stored, Base64.NO_WRAP)
        if (packed.size <= 12) return null
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, packed.copyOfRange(0, 12)))
        return String(cipher.doFinal(packed.copyOfRange(12, packed.size)), Charsets.UTF_8)
    }
}
