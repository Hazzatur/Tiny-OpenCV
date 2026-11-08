# Building the native library from source

`libopencv_java4.so` is not checked into this repository. It is built from
OpenCV's source by two scripts:

| Script | Purpose |
|---|---|
| `scripts/jitpack_prepare.sh` | Downloads the pinned toolchain and OpenCV source, verifies every download by sha256, builds all four ABIs into `openCV/src/main/jniLibs`, then optionally runs Gradle tasks. JitPack uses this script, and it is the easiest way to build locally. |
| `scripts/build_opencv_android.sh` | The build itself. It works with a toolchain you provide. |

## Quick start (Linux x86_64)

Requirements: `bash`, `curl`, `git`, `unzip`, `tar`, `sha256sum` and a JDK 17.

```bash
# Build the four ABIs, then assemble and install the AAR to ~/.m2
scripts/jitpack_prepare.sh :openCV:publishToMavenLocal
```

The toolchain is cached in `~/.cache/tiny-opencv-native`. Set `WORK` to use
another directory. The first run downloads about 1 GB, mostly the NDK. After
that, a full build takes a few minutes.

## What gets built

- OpenCV **4.11.0** (commit `31b0eeea0b44b370fd0712312df4214d4ae1b158`) with
  `BUILD_LIST=core,imgproc,java,java_bindings_generator`
- ABIs `armeabi-v7a`, `arm64-v8a`, `x86` and `x86_64`, at API level 26
- Static C++ runtime (`ANDROID_STL=c++_static`), OpenCV modules built as static
  libraries and linked into one `libopencv_java4.so`
- IPP-ICV, FastCV, ITT and OpenCL disabled
- HALs: carotene on ARM, plus KleidiCV 0.3.0 on arm64. The build fails if the
  HAL set differs from this, for example if the KleidiCV download failed.

Toolchain: Android NDK r29 (`29.0.14206865`), the Android SDK CMake 3.31.5
package (it includes ninja 1.10.2), and Python 3.12.15 for the bindings
generator.

## Reproducibility

The output does not depend on where or when the build runs:

- `-ffile-prefix-map` removes source, build and NDK paths.
- `SOURCE_DATE_EPOCH` is set to the OpenCV commit time.
- The configure summary OpenCV embeds in the library, and its sample-data
  paths, are sanitised.
- The libraries are stripped with the NDK's `llvm-strip`.

`BUILD_MANIFEST.txt` in the output directory records the toolchain versions and
the sha256 of each library. Two builds with the same inputs must produce the
same hashes.

## Using your own toolchain

```bash
scripts/build_opencv_android.sh \
  --opencv-src /path/to/opencv \
  --ndk /path/to/android-ndk-r29 \
  --cmake /path/to/cmake-3.31.5 \
  --python /path/to/python3 \
  --out /tmp/opencv-out \
  [--abi arm64-v8a ...] [--jobs N] [--download-cache DIR]
```

`ninja` must be on `PATH`. A different NDK, CMake or OpenCV version gives
different binaries, so use the pinned versions above to match a release.

## Java sources

The Java sources in `openCV/src/main/java` are kept from earlier releases for
API compatibility. They are a subset of OpenCV's generated bindings, and they
include `imgcodecs` wrappers whose native side is **not** built, so calling
them throws `UnsatisfiedLinkError`. The build generates a fresh copy under
`<out>/java` for comparison, but the build does not use it.
