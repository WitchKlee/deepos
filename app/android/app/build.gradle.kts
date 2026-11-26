import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProps = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

val hasWholeReleaseKey = listOf("storeFile", "keyAlias").all { !keyProps.getProperty(it).isNullOrBlank() } &&
    listOf("storePassword", "keyPassword").all { !keyProps.getProperty(it).isNullOrEmpty() } &&
    file(keyProps.getProperty("storeFile")).exists()

fun buildMinuteVersionCode(): Int {
    val t = OffsetDateTime.now(ZoneOffset.ofHours(8))
    return (t.year - 2026) * 100_000_000 + t.monthValue * 1_000_000 + t.dayOfMonth * 10_000 + t.hour * 100 + t.minute
}

android {
    namespace = "app.deepos"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // Exactly 10 ASCII characters matching "com.termux" for byte-equal
        // prefix rewriting (/data/data/com.termux/ -> /data/data/app.deepos/).
        applicationId = "app.deepos"
        manifestPlaceholders["appLabel"] = "DeepOS"
        minSdk = 26
        targetSdk = 28
        versionCode = flutter.versionCode.takeIf { it > 1 } ?: buildMinuteVersionCode()
        versionName = flutter.versionName

        ndk {
            abiFilters += "arm64-v8a"
        }
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=none")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    flavorDimensions += "sdk"
    productFlavors {
        create("sdk28") {
            dimension = "sdk"
            targetSdk = 28
            buildConfigField("boolean", "LOADER_EXEC", "false")
            buildConfigField("int", "TARGET_SDK_LEVEL", "28")
        }
        create("sdk36") {
            dimension = "sdk"
            targetSdk = 36
            buildConfigField("boolean", "LOADER_EXEC", "true")
            buildConfigField("int", "TARGET_SDK_LEVEL", "36")
        }
    }

    packaging {
        // Native shims, libldlinux.so, and libcc7zz.so must be extracted to
        // nativeLibraryDir so Android permits direct execution under both sdk28 and sdk36.
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += listOf(
                "**/libldlinux.so",
                "**/libcc7zz.so",
                "**/libccenosys.so",
                "**/libccenosysrun.so",
                "**/libccptyhost.so",
                "**/libccexecshim.so",
                "**/libccexecshimb.so",
                "**/libccrun.so",
                "**/libccnodump.so",
            )
        }
    }

    lint {
        disable += "ExpiredTargetSdkVersion"
    }

    androidResources {
        noCompress += listOf("gz", "xz", "zst", "tar")
    }

    signingConfigs {
        if (!keyProps.isEmpty) {
            create("release") {
                storeFile = keyProps.getProperty("storeFile")?.let { file(it) }
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        debug {
            if (hasWholeReleaseKey) signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName(if (keyProps.isEmpty) "debug" else "release")
            proguardFiles("proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Optional terminal `priv` & `cc-mem` helper over Shizuku (MIT). No AccessibilityService.
    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
