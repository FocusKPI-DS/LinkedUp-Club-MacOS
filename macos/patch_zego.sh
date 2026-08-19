#!/bin/bash
# Patch zego_express_engine errorCode for Xcode 26.2+ compatibility
ZEGO_FILE="$HOME/.pub-cache/hosted/pub.dev/zego_express_engine-3.24.1/macos/Classes/internal/ZegoExpressEngineEventHandler.m"
if [ -f "$ZEGO_FILE" ]; then
  if grep -q "info\.errorCode" "$ZEGO_FILE"; then
    sed -i '' 's/@(info\.errorCode)/@(0)/' "$ZEGO_FILE"
    echo "[patch_zego] Patched errorCode in ZegoExpressEngineEventHandler.m"
  fi
fi
