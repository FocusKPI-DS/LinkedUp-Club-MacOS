#!/bin/bash

# Simple script to test the production build locally

echo "Starting local server..."
echo "Visit http://localhost:3000 for landing page"
echo "Visit http://localhost:3000/app for Flutter app"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Install express if needed
if [ ! -d "node_modules/express" ]; then
  echo "Installing express..."
  npm install express
fi

# Run the test server
node test-local-server.js

