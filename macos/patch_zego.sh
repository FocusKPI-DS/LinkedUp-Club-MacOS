#!/bin/bash
# Patch zego_express_engine errorCode for Xcode 26.2+ compatibility.
# setup.sh copies ios/Classes/internal onto macos before compile, so patch both.
set -euo pipefail
PLUGIN_ROOT="${HOME}/.pub-cache/hosted/pub.dev/zego_express_engine-3.24.1"
for platform in ios macos; do
  ZEGO_FILE="${PLUGIN_ROOT}/${platform}/Classes/internal/ZegoExpressEngineEventHandler.m"
  if [ -f "$ZEGO_FILE" ] && grep -q "info\.errorCode" "$ZEGO_FILE"; then
    sed -i '' 's/@(info\.errorCode)/@(0)/' "$ZEGO_FILE"
    echo "[patch_zego] Patched errorCode in ${platform}/ZegoExpressEngineEventHandler.m"
  fi
done
