package com.tatertotterson.tatertubeplayer.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class SavedConnection(
    val serverUrl: String,
    val token: String,
    val playerName: String,
)

class CredentialStore(context: Context) {
    private val preferences = context.getSharedPreferences("tater_connection", Context.MODE_PRIVATE)
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    fun save(connection: SavedConnection) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.doFinal(connection.token.toByteArray(Charsets.UTF_8))
        preferences.edit()
            .putString("server_url", connection.serverUrl)
            .putString("player_name", connection.playerName)
            .putString("token_iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString("token_data", Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .apply()
    }

    fun load(): SavedConnection? = runCatching {
        val serverUrl = preferences.getString("server_url", null) ?: return null
        val playerName = preferences.getString("player_name", null) ?: "Tater Tube Player"
        val iv = Base64.decode(preferences.getString("token_iv", null), Base64.NO_WRAP)
        val encrypted = Base64.decode(preferences.getString("token_data", null), Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
        SavedConnection(serverUrl, String(cipher.doFinal(encrypted), Charsets.UTF_8), playerName)
    }.getOrNull()

    fun clear() {
        preferences.edit().clear().apply()
        if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
    }

    private fun secretKey(): SecretKey {
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build()
            )
            generateKey()
        }
    }

    private companion object {
        const val KEY_ALIAS = "tater_tube_player_pairing_token"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
