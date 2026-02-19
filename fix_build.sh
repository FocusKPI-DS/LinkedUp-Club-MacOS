#!/bin/bash
# fix_build.sh
# Forcefully replace DT_TOOLCHAIN_DIR with TOOLCHAIN_DIR in all pods xcconfig files
find macos/Pods -name "*.xcconfig" -print0 | xargs -0 sed -i '' 's/DT_TOOLCHAIN_DIR/TOOLCHAIN_DIR/g'
echo "Patched all .xcconfig files."
