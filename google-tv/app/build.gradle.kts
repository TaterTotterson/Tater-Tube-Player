plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val releaseSigningValues = mapOf(
    "storeFile" to System.getenv("ANDROID_SIGNING_STORE_FILE").orEmpty(),
    "storePassword" to System.getenv("ANDROID_SIGNING_STORE_PASSWORD").orEmpty(),
    "keyAlias" to System.getenv("ANDROID_SIGNING_KEY_ALIAS").orEmpty(),
    "keyPassword" to System.getenv("ANDROID_SIGNING_KEY_PASSWORD").orEmpty(),
)
val suppliedReleaseSigningValues = releaseSigningValues.filterValues { it.isNotBlank() }
if (suppliedReleaseSigningValues.isNotEmpty() && suppliedReleaseSigningValues.size != releaseSigningValues.size) {
    throw GradleException("Android release signing requires store file, store password, key alias, and key password.")
}

android {
    namespace = "com.tatertotterson.tatertubeplayer"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.tatertotterson.tatertubeplayer"
        minSdk = 23
        targetSdk = 37
        versionCode = System.getenv("TATER_TUBE_PLAYER_VERSION_CODE")?.toIntOrNull()?.takeIf { it > 0 } ?: 1
        versionName = System.getenv("TATER_TUBE_PLAYER_VERSION_NAME")?.trim()?.ifBlank { null } ?: "0.1.0"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (suppliedReleaseSigningValues.size == releaseSigningValues.size) {
            create("release") {
                storeFile = file(releaseSigningValues.getValue("storeFile"))
                storePassword = releaseSigningValues.getValue("storePassword")
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfigs.findByName("release")?.let { signingConfig = it }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources.excludes += setOf("/META-INF/{AL2.0,LGPL2.1}")
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.08.00")
    implementation(composeBom)

    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.19.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.tv:tv-material:1.1.0")
    implementation("androidx.tv:tv-foundation:1.0.0")
    implementation("androidx.tvprovider:tvprovider:1.1.0")

    implementation("androidx.media3:media3-exoplayer:1.11.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.11.1")
    implementation("androidx.media3:media3-ui:1.11.1")
    implementation("androidx.media3:media3-session:1.11.1")

    implementation("io.coil-kt.coil3:coil-compose:3.6.2")
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.6.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20260814")
}
