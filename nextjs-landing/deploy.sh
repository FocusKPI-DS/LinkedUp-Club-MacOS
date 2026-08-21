#!/bin/bash

# Build and deploy Next.js landing page to Firebase Hosting
# Run this from the project root directory

echo "🚀 Building Next.js landing page..."

cd "$(dirname "$0")"

# Build Next.js app
npm run build

if [ $? -ne 0 ]; then
  echo "❌ Build failed!"
  exit 1
fi

echo "✅ Build complete!"
echo ""
echo "📦 Output is in the 'out' directory"
echo ""
echo "🌐 To deploy to Firebase Hosting, run from project root:"
echo "   firebase deploy --only hosting"
echo ""
echo "Or deploy now? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  cd ..
  firebase deploy --only hosting
else
  echo "Build complete. Deploy manually when ready."
fi






