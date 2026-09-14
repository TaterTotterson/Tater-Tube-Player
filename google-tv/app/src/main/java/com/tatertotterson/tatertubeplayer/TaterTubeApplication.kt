package com.tatertotterson.tatertubeplayer

import android.app.Application
import coil3.ImageLoader
import coil3.SingletonImageLoader

class TaterTubeApplication : Application(), SingletonImageLoader.Factory {
    override fun newImageLoader(context: coil3.PlatformContext): ImageLoader =
        ImageLoader.Builder(context)
            .build()
}
