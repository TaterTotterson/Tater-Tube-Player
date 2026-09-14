package com.tatertotterson.tatertubeplayer.data

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Build
import androidx.tvprovider.media.tv.PreviewChannelHelper
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram
import com.tatertotterson.tatertubeplayer.model.MediaItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Keeps Android TV's system-owned Watch Next row aligned with Continue Watching. */
object WatchNextPublisher {
    private const val PreferencesName = "tater-watch-next"

    // These are the public builder calls used by Android's own Watch Next
    // documentation. tvprovider currently annotates their shared base builder
    // as library-group-only, so lint needs the narrow suppression here.
    @SuppressLint("RestrictedApi")
    suspend fun publish(context: Context, items: List<MediaItem>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        withContext(Dispatchers.IO) {
            val helper = PreviewChannelHelper(context)
            val preferences = context.getSharedPreferences(PreferencesName, Context.MODE_PRIVATE)
            val activeKeys = items
                .filter { it.progressPercent in 0.5..94.9 && it.viewOffsetMs > 0 }
                .mapTo(mutableSetOf()) { it.id }

            for (item in items.filter { it.id in activeKeys }) {
                val deepLink = Uri.Builder()
                    .scheme("tatertubeplayer")
                    .authority("continue")
                    .appendQueryParameter("id", item.id)
                    .appendQueryParameter("action", "play")
                    .build()
                val program = WatchNextProgram.Builder()
                    .setInternalProviderId(item.id)
                    .setType(if (item.isEpisode) TvContractCompat.PreviewPrograms.TYPE_TV_EPISODE else TvContractCompat.PreviewPrograms.TYPE_MOVIE)
                    .setWatchNextType(TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE)
                    .setTitle(item.title)
                    .setDescription(item.summary)
                    .setIntentUri(deepLink)
                    .setLastPlaybackPositionMillis(item.viewOffsetMs.coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
                    .setDurationMillis(item.durationMs.coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
                    .setLastEngagementTimeUtcMillis(System.currentTimeMillis())
                    .build()
                val existing = preferences.getLong(item.id, -1L)
                runCatching {
                    if (existing >= 0) {
                        helper.updateWatchNextProgram(program, existing)
                    } else {
                        val id = helper.publishWatchNextProgram(program)
                        preferences.edit().putLong(item.id, id).apply()
                    }
                }
            }

            val storedKeys = preferences.all.keys
            for (key in storedKeys - activeKeys) {
                val id = preferences.getLong(key, -1L)
                if (id >= 0) runCatching {
                    context.contentResolver.delete(TvContractCompat.buildWatchNextProgramUri(id), null, null)
                }
                preferences.edit().remove(key).apply()
            }
        }
    }

    suspend fun clear(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        withContext(Dispatchers.IO) {
            val preferences = context.getSharedPreferences(PreferencesName, Context.MODE_PRIVATE)
            for (id in preferences.all.values.filterIsInstance<Long>()) {
                runCatching {
                    context.contentResolver.delete(TvContractCompat.buildWatchNextProgramUri(id), null, null)
                }
            }
            preferences.edit().clear().apply()
        }
    }
}
