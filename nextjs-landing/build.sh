#!/bin/bash

# Build script to prepare Next.js landing page with Flutter app
# Run this from the project root directory

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Building Flutter web app..."
cd "$PROJECT_ROOT"
flutter build web --base-href /app/

echo "Copying Flutter build to Next.js public directory..."
cd "$SCRIPT_DIR"
mkdir -p public/app
cp -r "$PROJECT_ROOT/build/web/"* public/app/

echo "Fixing base href in Flutter index.html..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  sed -i '' 's|<base href="/">|<base href="/app/">|g' public/app/index.html
else
  # Linux
  sed -i 's|<base href="/">|<base href="/app/">|g' public/app/index.html
fi

echo "Building Next.js..."
npm run build

echo "Build complete! Output is in the 'out' directory."

