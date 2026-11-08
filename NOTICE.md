# Tiny-OpenCV notices

Tiny-OpenCV packages a reduced build of [OpenCV](https://opencv.org) 4.11.0: the
`core` and `imgproc` modules plus their Java bindings.

- The Java sources under `openCV/src/main/java` are OpenCV's generated Java
  bindings.
- The native library `libopencv_java4.so` is built from source by
  `scripts/build_opencv_android.sh`.
- The repository itself is licensed under the Apache License 2.0 (`LICENSE`).

The license texts listed below ship inside the AAR under `META-INF/tiny-opencv/`.
They are also available in the repository at
`openCV/src/main/resources/META-INF/tiny-opencv/`.

## Components compiled into `libopencv_java4.so`

| Component | Source | License | ABIs | License file |
|---|---|---|---|---|
| OpenCV `core`, `imgproc`, Java bindings | opencv/opencv 4.11.0 (`31b0eeea`) | Apache-2.0 | all | `OpenCV-LICENSE.txt`, `OpenCV-COPYRIGHT.txt` |
| Berkeley SoftFloat 3c (inside OpenCV `core`) | `modules/core/3rdparty/SoftFloat` | BSD-3-Clause | all | `SoftFloat-COPYING.txt` |
| cpufeatures (Android Open Source Project) | `3rdparty/cpufeatures` | Apache-2.0 | all | `cpufeatures-LICENSE.txt` |
| carotene / `tegra_hal` (NVIDIA) | `3rdparty/carotene` | BSD-3-Clause | armeabi-v7a, arm64-v8a | `carotene-LICENSE.txt` |
| KleidiCV 0.3.0 (Copyright 2023–2024 Arm Limited and/or its affiliates) | gitlab.arm.com/kleidi/kleidicv, tag `0.3.0` | Apache-2.0 | arm64-v8a | `KleidiCV-LICENSE.txt` |
| LLVM libc++ (from Android NDK r29), statically linked | Android NDK | Apache-2.0 WITH LLVM-exception | all | not required for binary redistribution (LLVM exception) |

The AAR also packages the NDK's `libc++_shared.so`, which is under the same
license as LLVM libc++, for compatibility with earlier releases.

Not included:
- Intel IPP-ICV, Qualcomm FastCV and Intel ITT are disabled at configure time.
- Image codec libraries are not built, because `imgcodecs` is not part of this
  build.

## Build provenance

The release build is pinned as follows. All downloads are verified by sha256 in
`scripts/jitpack_prepare.sh`.

- OpenCV `4.11.0`, commit `31b0eeea0b44b370fd0712312df4214d4ae1b158`
- Android NDK r29 `29.0.14206865`
- CMake `3.31.5` with ninja `1.10.2` (the Android SDK CMake package)
- Python `3.12.15` (python-build-standalone `20261013`)
- Android API level 26
- Static C++ runtime (`c++_static`)

The build is reproducible. Building the same inputs on different machines and
in different directories produces byte-identical libraries. Each build writes
the sha256 of every output to `BUILD_MANIFEST.txt`.
