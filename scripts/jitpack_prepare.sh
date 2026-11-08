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

NDK_URL=https://dl.google.com/android/repository/android-ndk-r29-linux.zip
NDK_SHA256=4abbbcdc842f3d4879206e9695d52709603e52dd68d3c1fff04b3b5e7a308ecf
CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.31.5/cmake-3.31.5-linux-x86_64.tar.gz
CMAKE_SHA256=2984e70515ff60c5e4a41922b5d715a8168a696a89721e3b114e36f453244f72
NINJA_URL=https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-linux.zip
NINJA_SHA256=6f98805688d19672bd699fbbfa2c2cf0fc054ac3df1f0e6a47664d963d530255
PYTHON_URL=https://github.com/astral-sh/python-build-standalone/releases/download/20261013/cpython-3.12.15%2B20261013-x86_64-unknown-linux-gnu-install_only.tar.gz
PYTHON_SHA256=5d546fc004fc2435fa142eb8f42ed8de5eb4725963dc22f7e6671014a80eb560
OPENCV_REPO=https://github.com/opencv/opencv.git
OPENCV_TAG=4.11.0
OPENCV_COMMIT=31b0eeea0b44b370fd0712312df4214d4ae1b158

verify() { echo "$2  $1" | sha256sum -c --quiet >/dev/null 2>&1; }

fetch() { # url sha256 out
  local url="$1" sha="$2" out="$3" i
  verify "$out" "$sha" && return 0
  for i in 1 2 3 4 5 6; do
    rm -f "$out"
    if curl -fsSL --connect-timeout 30 -o "$out" "$url" && verify "$out" "$sha"; then
      echo "    fetched $out"; return 0
    fi
    echo "    attempt $i failed for $url; retrying in $((i * 20))s" >&2
    sleep $((i * 20))
  done
  echo "error: could not fetch a verified copy of $url" >&2
  exit 1
}

t0=$(date +%s)
echo ">>> host: $(nproc) cpus, $(free -g | awk '/Mem:/{print $2}') GB RAM, system $(python3 --version 2>&1)"
echo ">>> $(curl --version | head -1)"
echo ">>> ANDROID_HOME=${ANDROID_HOME:-unset}; preinstalled NDKs: $(ls "${ANDROID_HOME:-/nonexistent}/ndk" 2>/dev/null | tr '\n' ' ')"
echo ">>> proxy vars: $(env | grep -ic '_proxy=' || true)"

fetch "$NDK_URL" "$NDK_SHA256" ndk.zip
fetch "$CMAKE_URL" "$CMAKE_SHA256" cmake.tar.gz
fetch "$NINJA_URL" "$NINJA_SHA256" ninja.zip
fetch "$PYTHON_URL" "$PYTHON_SHA256" python.tar.gz
[[ -d android-ndk-r29 ]] || unzip -q ndk.zip
[[ -d cmake-3.31.5-linux-x86_64 ]] || tar xzf cmake.tar.gz
[[ -d python ]] || tar xzf python.tar.gz
mkdir -p bin; [[ -x bin/ninja ]] || unzip -q -o ninja.zip -d bin
export PATH="$WORK/bin:$PATH"

if [[ ! -d opencv ]]; then
  for i in 1 2 3 4; do
    git clone -q --depth 1 --branch "$OPENCV_TAG" "$OPENCV_REPO" opencv && break
    rm -rf opencv; echo "    clone attempt $i failed; retrying" >&2; sleep $((i * 20))
  done
fi
[[ "$(git -C opencv rev-parse HEAD)" == "$OPENCV_COMMIT" ]] || { echo "error: OpenCV commit mismatch" >&2; exit 1; }
echo ">>> toolchain ready in $(( $(date +%s) - t0 ))s"

"$ROOT/scripts/build_opencv_android.sh" \
  --opencv-src opencv --ndk android-ndk-r29 --cmake cmake-3.31.5-linux-x86_64 \
  --python "$WORK/python/bin/python3" \
  --out "$WORK/out" --download-cache "$WORK/downloads"

cp -r "$WORK/out/jniLibs" "$JNILIBS"
echo ">>> native build finished in $(( $(date +%s) - t0 ))s total"
