#!/usr/bin/env bash
# Fetches the pinned, checksum-verified toolchain + OpenCV source and builds the native
# libraries into openCV/src/main/jniLibs. Used by jitpack.yml; also runnable locally.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$ROOT/build/native-toolchain}"
mkdir -p "$WORK"; cd "$WORK"

NDK_URL=https://dl.google.com/android/repository/android-ndk-r29-linux.zip
NDK_SHA256=4abbbcdc842f3d4879206e9695d52709603e52dd68d3c1fff04b3b5e7a308ecf
CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.31.5/cmake-3.31.5-linux-x86_64.tar.gz
CMAKE_SHA256=2984e70515ff60c5e4a41922b5d715a8168a696a89721e3b114e36f453244f72
NINJA_URL=https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-linux.zip
NINJA_SHA256=6f98805688d19672bd699fbbfa2c2cf0fc054ac3df1f0e6a47664d963d530255
OPENCV_REPO=https://github.com/opencv/opencv.git
OPENCV_TAG=4.11.0
OPENCV_COMMIT=31b0eeea0b44b370fd0712312df4214d4ae1b158

fetch() { # url sha256 out
  [[ -f "$3" ]] && echo "$2  $3" | sha256sum -c --quiet 2>/dev/null && return 0
  curl -fsSL --retry 3 -o "$3" "$1"
  echo "$2  $3" | sha256sum -c --quiet
}

t0=$(date +%s)
echo ">>> host: $(nproc) cpus, $(free -g | awk '/Mem:/{print $2}') GB RAM, $(python3 --version 2>&1)"
fetch "$NDK_URL" "$NDK_SHA256" ndk.zip
fetch "$CMAKE_URL" "$CMAKE_SHA256" cmake.tar.gz
fetch "$NINJA_URL" "$NINJA_SHA256" ninja.zip
[[ -d android-ndk-r29 ]] || unzip -q ndk.zip
[[ -d cmake-3.31.5-linux-x86_64 ]] || tar xzf cmake.tar.gz
mkdir -p bin; [[ -x bin/ninja ]] || unzip -q -o ninja.zip -d bin
export PATH="$WORK/bin:$PATH"

if [[ ! -d opencv ]]; then
  git clone -q --depth 1 --branch "$OPENCV_TAG" "$OPENCV_REPO" opencv
fi
[[ "$(git -C opencv rev-parse HEAD)" == "$OPENCV_COMMIT" ]] || { echo "OpenCV commit mismatch" >&2; exit 1; }
echo ">>> toolchain ready in $(( $(date +%s) - t0 ))s"

"$ROOT/scripts/build_opencv_android.sh" \
  --opencv-src opencv --ndk android-ndk-r29 --cmake cmake-3.31.5-linux-x86_64 \
  --out "$WORK/out" --download-cache "$WORK/downloads"

rm -rf "$ROOT/openCV/src/main/jniLibs"
cp -r "$WORK/out/jniLibs" "$ROOT/openCV/src/main/jniLibs"
echo ">>> native build finished in $(( $(date +%s) - t0 ))s total"
