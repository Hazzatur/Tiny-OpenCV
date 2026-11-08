# Tiny-OpenCV

[![JitPack](https://jitpack.io/v/Hazzatur/Tiny-OpenCV.svg)](https://jitpack.io/#Hazzatur/Tiny-OpenCV)

> **Legacy, frozen.** `4.11.0-4` is the final release of Tiny-OpenCV. It will get
> no further updates. [Document-Scanning-Android-SDK](https://github.com/Hazzatur/Document-Scanning-Android-SDK)
> will build its own OpenCV from version 2.0 and will no longer depend on this library.
> Existing versions remain available on JitPack.

A tiny version of [OpenCV](https://opencv.org) for Android. It contains only the
`core` and `imgproc` modules and their Java bindings. The native library is
**built from source, reproducibly**: no prebuilt binaries are checked in.

- Tiny version of OpenCV **4.11.0**. `libopencv_java4.so` per ABI:
    - arm64-v8a: **7.5 MB** (original: 21.6 MB)
    - armeabi-v7a: **5.0 MB** (original: 14.8 MB)
    - x86: **9.0 MB** (original: 39.5 MB)
    - x86_64: **10.7 MB** (original: 53.2 MB)
- Minimum Android API level: 26

## Installation

In your app's Gradle file:

    dependencies {
        ...
        implementation 'com.github.Hazzatur:Tiny-OpenCV:4.11.0-4'
    }

In your root Gradle file:

	allprojects {
	    repositories {
		...
		maven { url "https://jitpack.io" }
	    }
	}

Load the library before using any OpenCV class:

```kotlin
System.loadLibrary("opencv_java4")
```

`4.11.0-4` is a drop-in replacement for `4.11.0-2`: it has the same Java API, the
same exported JNI functions and the same set of native libraries. The only additions are
the license notices under `META-INF/tiny-opencv/`. Only how the native libraries
are produced has changed.

The `org.opencv.imgcodecs` classes are still present for compatibility, but
their native code is not built. Calling them throws `UnsatisfiedLinkError`.

## Building

See [how_to.md](how_to.md). In short:

```bash
scripts/jitpack_prepare.sh :openCV:publishToMavenLocal
```

This downloads a pinned, checksum-verified toolchain (Android NDK r29,
CMake 3.31.5 and Python 3.12) and OpenCV 4.11.0. It builds all four ABIs from
source and produces byte-identical libraries on any machine. JitPack runs the
same script.

## License

Apache License 2.0. See [LICENSE](LICENSE). The native library includes OpenCV
and a few bundled components, each under its own license; see
[NOTICE.md](NOTICE.md). The license texts also ship inside the AAR under
`META-INF/tiny-opencv/`.
