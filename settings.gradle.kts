pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven(url = "https://jitpack.io")
    }
}
rootProject.name = "TinyOpenCV"
include(":app", ":openCV")
