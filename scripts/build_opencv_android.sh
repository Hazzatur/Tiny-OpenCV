#!/usr/bin/env bash
# Reproducible source build of the Tiny-OpenCV native library (libopencv_java4.so)
# and its generated Java wrappers.
#
# Usage:
#   scripts/build_opencv_android.sh --opencv-src DIR --ndk DIR --out DIR \
#       [--cmake DIR_WITH_BIN] [--abi ABI]... [--build-root DIR] [--jobs N] \
#       [--download-cache DIR] [--python PYTHON3]
#
# Defaults: all four ABIs, build root = <out>/.build, jobs = nproc.
# Output layout:
#   <out>/jniLibs/<abi>/libopencv_java4.so
#   <out>/java/                          (generated wrappers, from the first ABI)
#   <out>/BUILD_MANIFEST.txt             (inputs + sha256 of outputs)
#
# Reproducibility measures:
#   * absolute paths are mapped away with -ffile-prefix-map (covers __FILE__ and debug info)
#   * SOURCE_DATE_EPOCH defaults to the OpenCV source commit time (CMake TIMESTAMP honours it)
#   * the configure summary embedded in the library (version_string.inc) is sanitised
#   * outputs are stripped with the NDK's llvm-strip
#   * KleidiCV (arm64 HAL) is fetched by OpenCV's own pinned-hash downloader into a cache dir;
#     pass --download-cache with a pre-populated cache for offline builds
#   * proprietary/binary-blob options are forced off (IPP-ICV, FastCV)
set -euo pipefail

OPENCV_SRC="" NDK="" OUT="" CMAKE_DIR="" BUILD_ROOT="" JOBS="$(nproc)" DL_CACHE="" PYTHON=""
ABIS=()
API_LEVEL=26

die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opencv-src) OPENCV_SRC="$2"; shift 2 ;;
    --ndk) NDK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --cmake) CMAKE_DIR="$2"; shift 2 ;;
    --abi) ABIS+=("$2"); shift 2 ;;
    --build-root) BUILD_ROOT="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --download-cache) DL_CACHE="$2"; shift 2 ;;
    --python) PYTHON="$2"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$OPENCV_SRC" && -d "$OPENCV_SRC" ]] || die "--opencv-src must point to an OpenCV checkout"
[[ -n "$NDK" && -f "$NDK/build/cmake/android.toolchain.cmake" ]] || die "--ndk must point to an Android NDK"
[[ -n "$OUT" ]] || die "--out is required"
[[ ${#ABIS[@]} -gt 0 ]] || ABIS=(armeabi-v7a arm64-v8a x86 x86_64)

OPENCV_SRC="$(realpath "$OPENCV_SRC")"
NDK="$(realpath "$NDK")"
mkdir -p "$OUT"; OUT="$(realpath "$OUT")"
BUILD_ROOT="${BUILD_ROOT:-$OUT/.build}"; mkdir -p "$BUILD_ROOT"; BUILD_ROOT="$(realpath "$BUILD_ROOT")"
DL_CACHE="${DL_CACHE:-$BUILD_ROOT/downloads}"; mkdir -p "$DL_CACHE"; DL_CACHE="$(realpath "$DL_CACHE")"

if [[ -n "$CMAKE_DIR" ]]; then CMAKE="$(realpath "$CMAKE_DIR")/bin/cmake"; else CMAKE="$(command -v cmake)"; fi
[[ -x "$CMAKE" ]] || die "cmake not found"
command -v ninja >/dev/null || die "ninja not found"
PYTHON="${PYTHON:-$(command -v python3 || true)}"
[[ -n "$PYTHON" && -x "$PYTHON" ]] || die "python3 not found (needed by the Java bindings generator)"
PYTHON="$(realpath "$PYTHON")"
STRIP="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"

OPENCV_COMMIT="$(git -C "$OPENCV_SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
  SOURCE_DATE_EPOCH="$(git -C "$OPENCV_SRC" log -1 --format=%ct 2>/dev/null || echo 0)"
fi
export SOURCE_DATE_EPOCH
# PYTHONHASHSEED: keeps the bindings generator's set/dict iteration order stable.
export LC_ALL=C TZ=UTC PYTHONHASHSEED=0
NDK_REV="$(sed -n 's/^Pkg.Revision *= *//p' "$NDK/source.properties")"
CMAKE_VER="$("$CMAKE" --version | head -1 | awk '{print $3}')"
PYTHON_VER="$("$PYTHON" -c 'import platform; print(platform.python_version())')"
NINJA_VER="$(ninja --version)"

sanitize_build_info() {
  # $1 = build dir. Rewrites the configure summary compiled into libopencv_core.
  local inc="$1/modules/core/version_string.inc"
  [[ -f "$inc" ]] || die "version_string.inc not found in $1"
  "$PYTHON" -I - "$inc" "$NDK" "$OPENCV_SRC" "$1" "$CMAKE" "$PYTHON" "$(command -v ninja)" <<'PY'
import re, sys
path, ndk, src, bld, cmake, py, ninja = sys.argv[1:]
s = open(path, encoding="utf-8").read()
for real, tag in sorted([(ndk, "<NDK>"), (src, "<SRC>"), (bld, "<BUILD>"),
                         (cmake, "cmake"), (py, "python3"), (ninja, "ninja")],
                        key=lambda p: -len(p[0])):
    s = s.replace(real, tag)
s = re.sub(r'(Host:\s+)[^"\\]*', r'\1Linux x86_64', s)
s = re.sub(r'(Install to:\s+)[^"\\]*', r'\1<INSTALL>', s)
open(path, "w", encoding="utf-8").write(s)
PY
  # opencv_data_config.hpp: sample-data lookup paths (cv::samples::findFile), unused on Android,
  # but they embed the absolute build dir and the build->source relative path.
  local dcfg="$1/opencv_data_config.hpp"
  [[ -f "$dcfg" ]] || die "opencv_data_config.hpp not found in $1"
  "$PYTHON" -I - "$dcfg" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = re.sub(r'(#define OPENCV_BUILD_DIR )"[^"]*"', r'\1"/build"', s)
s = re.sub(r'(#define OPENCV_DATA_BUILD_DIR_SEARCH_PATHS \\\n\s*)"[^"]*"', r'\1"../opencv/"', s)
open(p, "w", encoding="utf-8").write(s)
PY
}

MANIFEST="$OUT/BUILD_MANIFEST.txt"
{
  echo "opencv_commit=$OPENCV_COMMIT"
  echo "ndk_revision=$NDK_REV"
  echo "cmake_version=$CMAKE_VER"
  echo "ninja_version=$NINJA_VER"
  echo "python_version=$PYTHON_VER"
  echo "android_api=$API_LEVEL"
  echo "source_date_epoch=$SOURCE_DATE_EPOCH"
} > "$MANIFEST"

JAVA_COPIED=0
for ABI in "${ABIS[@]}"; do
  BDIR="$BUILD_ROOT/$ABI"
  rm -rf "$BDIR"; mkdir -p "$BDIR"
  # Quoted so paths containing spaces survive CMake's flag-string splitting.
  PREFIX_MAP="\"-ffile-prefix-map=$OPENCV_SRC=/opencv\" \"-ffile-prefix-map=$BDIR=/build\" \"-ffile-prefix-map=$NDK=/ndk\""
  echo ">>> configuring $ABI"
  "$CMAKE" -S "$OPENCV_SRC" -B "$BDIR" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM="android-$API_LEVEL" \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$PREFIX_MAP" \
    -DCMAKE_CXX_FLAGS="$PREFIX_MAP" \
    -DOPENCV_DOWNLOAD_PATH="$DL_CACHE" \
    -DPYTHON_DEFAULT_EXECUTABLE="$PYTHON" \
    -DPYTHON3_EXECUTABLE="$PYTHON" \
    -DCMAKE_INSTALL_PREFIX=/opencv-install \
    -DBUILD_LIST=core,imgproc,java,java_bindings_generator \
    -DANDROID_PROJECTS_BUILD_TYPE=GRADLE \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_JAVA=ON \
    -DBUILD_ANDROID_PROJECTS=OFF \
    -DBUILD_ANDROID_EXAMPLES=OFF \
    -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_DOCS=OFF \
    -DBUILD_opencv_apps=OFF \
    -DWITH_IPP=OFF -DWITH_FASTCV=OFF -DWITH_OPENCL=OFF \
    -DOPENCV_ENABLE_NONFREE=OFF \
    > "$BDIR/configure.log" 2>&1 || { tail -40 "$BDIR/configure.log"; die "configure failed for $ABI"; }
  sanitize_build_info "$BDIR"

  echo ">>> building $ABI"
  start=$(date +%s)
  # Only the native library and the assembled Java sources. The default "all" target also
  # includes opencv_java_android, which runs OpenCV's bundled Gradle wrapper (network download).
  "$CMAKE" --build "$BDIR" -j "$JOBS" --target opencv_java opencv_java_android_source_copy \
    > "$BDIR/build.log" 2>&1 || { tail -40 "$BDIR/build.log"; die "build failed for $ABI"; }
  echo "    $ABI built in $(( $(date +%s) - start ))s"

  SO="$BDIR/jni/$ABI/libopencv_java4.so"
  [[ -f "$SO" ]] || SO="$(find "$BDIR" -name libopencv_java4.so | head -1)"
  [[ -f "$SO" ]] || die "libopencv_java4.so not produced for $ABI"
  mkdir -p "$OUT/jniLibs/$ABI"
  "$STRIP" --strip-all -R .comment -o "$OUT/jniLibs/$ABI/libopencv_java4.so" "$SO"

  if [[ $JAVA_COPIED -eq 0 ]]; then
    GEN="$BDIR/opencv_android/opencv/src"
    [[ -d "$GEN/org/opencv" ]] || die "generated Java sources not found at $GEN"
    rm -rf "$OUT/java"; mkdir -p "$OUT/java"
    cp -r "$GEN/." "$OUT/java/"
    JAVA_COPIED=1
  fi
done

echo "--- outputs" >> "$MANIFEST"
( cd "$OUT" && find jniLibs -name '*.so' | sort | xargs sha256sum ) >> "$MANIFEST"
echo ">>> done; manifest: $MANIFEST"
cat "$MANIFEST"
