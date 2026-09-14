package com.tatertotterson.tatertubeplayer.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class TaterApiClientTest {
    @Test
    fun normalizesPrivateServerAddress() {
        assertEquals(
            "http://10.4.20.59:8000",
            TaterApiClient.normalizeServerUrl("10.4.20.59:8000/"),
        )
    }

    @Test
    fun permitsSecureRemoteServer() {
        assertEquals(
            "https://media.example.com/tater",
            TaterApiClient.normalizeServerUrl("https://media.example.com/tater/"),
        )
    }

    @Test
    fun rejectsPublicCleartextServer() {
        assertThrows(IllegalArgumentException::class.java) {
            TaterApiClient.normalizeServerUrl("http://media.example.com")
        }
    }
}
