import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
} else if (releaseBuildRequested) {
    throw GradleException(
        "Release signing is not configured. Create android/key.properties " +
            "as described in docs/android_release_builds.md.",
    )
}

fun requiredSigningProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException(
            "Missing '$name' in android/key.properties. " +
                "See docs/android_release_builds.md.",
        )

dependencies {
    implementation("androidx.core:core:1.17.0")
    implementation("androidx.media:media:1.7.0")
}

android {
    namespace = "com.example.jwsongbook"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    lint {
        // The app only posts MediaSession notifications, which Android exempts
        // from the Android 13 notification runtime permission behavior.
        disable += "NotificationPermission"
        // Flutter regenerates local.properties with Windows path separators.
        disable += "PropertyEscape"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.jwsongbook"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
                storeFile = rootProject.file(requiredSigningProperty("storeFile"))
                storePassword = requiredSigningProperty("storePassword")

                if (releaseBuildRequested && !storeFile!!.isFile) {
                    throw GradleException(
                        "Release keystore does not exist: ${storeFile!!.absolutePath}",
                    )
                }
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to Flutter's shared debug certificate for releases.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
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
