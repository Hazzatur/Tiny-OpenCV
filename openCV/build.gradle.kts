plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

android {
    namespace = "org.opencv"
    compileSdk = 35

    defaultConfig {
        minSdk = 26

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=c++_shared")
                targets += listOf("opencv_jni_shared")
            }
        }
    }

    buildTypes {
        named("debug") {
            packaging {
                jniLibs.keepDebugSymbols.add("**/*.so")
            }
        }
        named("release") {
            packaging {
                jniLibs.keepDebugSymbols.add("**/*.so")
            }
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.txt"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/main/java")
            jniLibs.srcDirs("src/main/jniLibs")
            res.srcDirs("src/main/res")
            manifest.srcFile("src/main/AndroidManifest.xml")
        }
    }

    externalNativeBuild {
        cmake {
            path = File(project.projectDir, "libcxx_helper/CMakeLists.txt")
        }
    }
}

tasks.register<Jar>("sourceJar") {
    from(android.sourceSets["main"].java.srcDirs)
    from(fileTree(mapOf("dir" to "src/libs", "include" to listOf("*.jar"))))
    archiveClassifier.set("sources")
}

tasks.register<Jar>("androidSourcesJar") {
    archiveClassifier.set("sources")
    from(android.sourceSets["main"].java.srcDirs)
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])
                groupId = "com.github.hazzatur"
                artifactId = "Tiny-OpenCV"
                version = System.getenv("VERSION") ?: "4.11.0-3"
            }
        }
    }
}

dependencies {
    implementation(libs.kotlin.stdlib)
    implementation(libs.androidx.core.ktx)
}
