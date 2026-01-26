#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting deployment process..."

# Step 1: Build Next.js landing page
echo "📦 Building Next.js landing page..."
cd nextjs-landing
npm run build
cd ..

# Step 2: Clean and build Flutter web app
echo "📦 Building Flutter web app..."
flutter clean
rm -rf build/web
flutter pub get
flutter build web --release --base-href /app/

# Step 3: Copy Flutter build to Next.js output under /app
echo "📋 Copying Flutter app to /app directory..."
rm -rf nextjs-landing/out/app
mkdir -p nextjs-landing/out/app
cp -r build/web/* nextjs-landing/out/app/

# Step 3.5: Fix flutter_bootstrap_js placeholder in index.html
echo "🔧 Fixing flutter_bootstrap_js reference..."
if [ -f "nextjs-landing/out/app/index.html" ]; then
  # Replace the entire script block containing the placeholder with the actual script tag
  perl -i -0pe 's/<script>\s*\{\s*\{\s*flutter_bootstrap_js\s*\}\s*\}\s*<\/script>/<script src="flutter_bootstrap.js"><\/script>/gs' nextjs-landing/out/app/index.html
  echo "✅ Fixed index.html"
else
  echo "⚠️  Warning: index.html not found in app directory"
fi

# Step 4: Deploy to Firebase
echo "🔥 Deploying to Firebase..."
firebase deploy --only hosting

echo ""
echo "✅ Deployment complete!"
echo "🌐 Landing page: https://linkedup-c3e29.web.app"
echo "🌐 Flutter app: https://linkedup-c3e29.web.app/app"
echo ""
echo "💡 If you still see old version:"
echo "   1. Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)"
echo "   2. Clear browser cache"
echo "   3. Try incognito mode"
