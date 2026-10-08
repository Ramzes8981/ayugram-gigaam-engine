#!/usr/bin/env bash
set -euo pipefail
SOURCE="${1:-android-engine-arm64}"
PKG='com.radolyn.ayugram'
APP_DIR="/data/user/0/$PKG/code_cache/asr_engine"
if [[ ! -f "$SOURCE/libtranscribe.so" ]]; then
  echo 'Missing libtranscribe.so. Pass unpacked GitHub Actions artifact directory.' >&2
  exit 1
fi
adb devices
adb shell su -c id >/dev/null || { echo 'Root / su needed for copying files to AyuGram sandbox' >&2; exit 1; }
adb shell 'mkdir -p /sdcard/Download/ayugram-asr-engine'
for name in "$SOURCE"/*.so; do
  [[ -f "$name" ]] || continue
  adb push "$name" '/sdcard/Download/ayugram-asr-engine/'
done
adb shell su -c "mkdir -p '$APP_DIR'; cp /sdcard/Download/ayugram-asr-engine/*.so '$APP_DIR/'; APP_UID=\$(stat -c %u /data/user/0/$PKG); chown -R \$APP_UID:\$APP_UID '$APP_DIR'; chmod 700 '$APP_DIR'; chmod 400 '$APP_DIR'/*.so; restorecon -RF '$APP_DIR' 2>/dev/null || true"
echo "Done: $APP_DIR"
echo 'Restart AyuGram. Then tap Check native engine and model in the plugin settings.'
