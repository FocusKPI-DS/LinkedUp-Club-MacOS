#!/bin/bash

set -e

echo "🚀 Building and deploying Flutter web app..."
echo ""

# Build Flutter web
echo "📦 Building Flutter web..."
flutter build web --release --web-renderer canvaskit

echo ""
echo "🔥 Deploying to Firebase..."
firebase deploy --only hosting

echo ""
echo "✅ Deployment complete!"
echo "🌐 App URL: https://linkedup-c3e29.web.app"
echo ""
echo "💡 Hard refresh to see changes: Cmd+Shift+R"
