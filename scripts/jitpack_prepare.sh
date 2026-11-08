#!/usr/bin/env bash
# Fetches the pinned, checksum-verified toolchain + OpenCV source and builds the native
# libraries into openCV/src/main/jniLibs. Used by jitpack.yml; also runnable locally.
#
# The committed jniLibs are deleted first, so a failure here can never lead to the old
# prebuilt binaries being published.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$ROOT/build/native-toolchain}"
JNILIBS="$ROOT/openCV/src/main/jniLibs"
rm -rf "$JNILIBS"
mkdir -p "$WORK"; cd "$WORK"

# Every archive is verified by sha256, so mirrors are interchangeable. URLs are tried in order.
# NDK and CMake (which bundles ninja) are the Android SDK packages from dl.google.com.
NDK_URLS=(https://dl.google.com/android/repository/android-ndk-r29-linux.zip)
NDK_SHA256=4abbbcdc842f3d4879206e9695d52709603e52dd68d3c1fff04b3b5e7a308ecf
CMAKE_URLS=(https://dl.google.com/android/repository/cmake-3.31.5-linux.zip)
CMAKE_SHA256=8b6fb3c42ffc5294694ee02fffaf2d12cf0793768dea2be40666a272c3e1b63f
PYTHON_FILE=cpython-3.12.15%2B20261013-x86_64-unknown-linux-gnu-install_only.tar.gz
PYTHON_URLS=(
  "https://releases.astral.sh/github/python-build-standalone/releases/download/20261013/$PYTHON_FILE"
  "https://github.com/astral-sh/python-build-standalone/releases/download/20261013/$PYTHON_FILE"
)
PYTHON_SHA256=5d546fc004fc2435fa142eb8f42ed8de5eb4725963dc22f7e6671014a80eb560
# KleidiCV (arm64 HAL) is pre-seeded into OpenCV's download cache under the name and MD5 that
# OpenCV 4.11.0 expects (3rdparty/kleidicv/kleidicv.cmake), so configure never downloads it.
KLEIDICV_URLS=(https://gitlab.arm.com/kleidi/kleidicv/-/archive/0.3.0/kleidicv-0.3.0.tar.gz)
KLEIDICV_SHA256=7ac74f74b4e7cd9cd6b4d9c77ec2aa6fcabd3271e61051efd8ac95c1a5a5fabb
KLEIDICV_CACHE=downloads/kleidicv/51a77b0185c2bac2a968a2163869b1ed-kleidicv-0.3.0.tar.gz
# Gradle: the version pinned by the wrapper, verified against its distributionSha256Sum.
# services.gradle.org redirects to GitHub releases; the other two serve the file directly.
WRAPPER_PROPS="$ROOT/gradle/wrapper/gradle-wrapper.properties"
GRADLE_VERSION="$(sed -n 's/^distributionUrl=.*gradle-\([0-9.]*\)-bin\.zip$/\1/p' "$WRAPPER_PROPS")"
GRADLE_SHA256="$(sed -n 's/^distributionSha256Sum=//p' "$WRAPPER_PROPS")"
[[ -n "$GRADLE_VERSION" && -n "$GRADLE_SHA256" ]] || { echo "error: cannot read Gradle pin from $WRAPPER_PROPS" >&2; exit 1; }
GRADLE_URLS=(
  "https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip"
  "https://downloads.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip"
  "https://mirrors.cloud.tencent.com/gradle/gradle-$GRADLE_VERSION-bin.zip"
)
OPENCV_REPO=https://github.com/opencv/opencv.git
OPENCV_TAG=4.11.0
OPENCV_COMMIT=31b0eeea0b44b370fd0712312df4214d4ae1b158

verify() { echo "$2  $1" | sha256sum -c --quiet >/dev/null 2>&1; }

fetch() { # out sha256 url...
  local out="$1" sha="$2" i url; shift 2
  verify "$out" "$sha" && return 0
  mkdir -p "$(dirname "$out")"
  for i in 1 2 3 4 5; do
    for url in "$@"; do
      rm -f "$out"
      if curl -fsSL --connect-timeout 30 -o "$out" "$url" && verify "$out" "$sha"; then
        echo "    fetched $out from ${url%%\?*}"; return 0
      fi
      echo "    attempt $i failed: ${url%%\?*}" >&2
    done
    sleep $((i * 20))
  done
  echo "error: could not fetch a verified copy of $out" >&2
  exit 1
}

t0=$(date +%s)
echo ">>> host: $(nproc) cpus, $(free -g | awk '/Mem:/{print $2}') GB RAM, system $(python3 --version 2>&1)"
echo ">>> ANDROID_HOME=${ANDROID_HOME:-unset}; preinstalled NDKs: $(ls "${ANDROID_HOME:-/nonexistent}/ndk" 2>/dev/null | tr '\n' ' ')"

fetch ndk.zip "$NDK_SHA256" "${NDK_URLS[@]}"
fetch cmake.zip "$CMAKE_SHA256" "${CMAKE_URLS[@]}"
fetch python.tar.gz "$PYTHON_SHA256" "${PYTHON_URLS[@]}"
fetch "$KLEIDICV_CACHE" "$KLEIDICV_SHA256" "${KLEIDICV_URLS[@]}"
fetch gradle.zip "$GRADLE_SHA256" "${GRADLE_URLS[@]}"
[[ -d android-ndk-r29 ]] || unzip -q ndk.zip
[[ -d cmake-3.31.5 ]] || { mkdir cmake-3.31.5 && unzip -q cmake.zip -d cmake-3.31.5; }
[[ -d python ]] || tar xzf python.tar.gz
[[ -d "gradle-$GRADLE_VERSION" ]] || unzip -q gradle.zip
ln -sfn "gradle-$GRADLE_VERSION" gradle
export PATH="$WORK/cmake-3.31.5/bin:$PATH"   # provides ninja

if [[ ! -d opencv ]]; then
  for i in 1 2 3 4 5; do
    git clone -q --depth 1 --branch "$OPENCV_TAG" "$OPENCV_REPO" opencv && break
    rm -rf opencv; echo "    clone attempt $i failed; retrying" >&2; sleep $((i * 20))
  done
fi
[[ "$(git -C opencv rev-parse HEAD)" == "$OPENCV_COMMIT" ]] || { echo "error: OpenCV commit mismatch" >&2; exit 1; }
echo ">>> toolchain ready in $(( $(date +%s) - t0 ))s"

"$ROOT/scripts/build_opencv_android.sh" \
  --opencv-src opencv --ndk android-ndk-r29 --cmake cmake-3.31.5 \
  --python "$WORK/python/bin/python3" \
  --out "$WORK/out" --download-cache "$WORK/downloads"

cp -r "$WORK/out/jniLibs" "$JNILIBS"
echo ">>> native build finished in $(( $(date +%s) - t0 ))s total"
