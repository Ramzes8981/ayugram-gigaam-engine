#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/transcribe.cpp"
OUT="$ROOT/android-engine-arm64"
COMMIT="95d82e5134fba4b18ad6a46f3baf950f53bcfc3b"
: "${ANDROID_NDK_HOME:?ANDROID_NDK_HOME must refer to an installed Android NDK}"
if [[ ! -d "$SRC" ]]; then
  git clone --recursive https://github.com/handy-computer/transcribe.cpp.git "$SRC"
fi
git -C "$SRC" fetch origin "$COMMIT" --depth 1
git -C "$SRC" checkout --detach "$COMMIT"
git -C "$SRC" submodule update --init --recursive
cmake -S "$SRC" -B "$ROOT/build-android" -G Ninja \
 -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
 -DCMAKE_BUILD_TYPE=Release \
 -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DANDROID_STL=c++_static \
 -DTRANSCRIBE_BUILD_SHARED=ON -DTRANSCRIBE_BUILD_EXAMPLES=OFF \
 -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_TOOLS=OFF \
 -DTRANSCRIBE_USE_OPENMP=OFF -DTRANSCRIBE_USE_SYSTEM_BLAS=OFF \
 -DTRANSCRIBE_METAL=OFF -DTRANSCRIBE_VULKAN=OFF -DTRANSCRIBE_CUDA=OFF \
 -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_BLAS=OFF
cmake --build "$ROOT/build-android" -j 2
mkdir -p "$OUT"
find "$ROOT/build-android" -type f \( -name 'libtranscribe.so' -o -name 'libggml*.so' \) -exec cp -v '{}' "$OUT" ';'
test -s "$OUT/libtranscribe.so"
find "$OUT" -maxdepth 1 -name '*.so' -exec file '{}' ';'
if command -v llvm-readelf >/dev/null; then
  llvm-readelf -h "$OUT/libtranscribe.so" | grep -E 'Machine:|Class:'
fi
( cd "$OUT" && sha256sum ./*.so > SHA256SUMS )
cat > "$OUT/VERSION.txt" <<EOF
transcribe.cpp $COMMIT
Android arm64-v8a API26, cpu
EOF
printf 'Build outputs: %s\n' "$OUT"
