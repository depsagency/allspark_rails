#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# Check if node_modules exists, install if not
if [ ! -d /app/node_modules ] || [ ! -f /app/node_modules/.bin/esbuild ]; then
  echo "Node modules not found. Installing dependencies..."
  yarn install
  echo "Dependencies installed successfully"
fi

# Check if assets need to be compiled
if [ ! -f /app/public/assets/.manifest.json ] || [ -z "$(ls -A /app/app/assets/builds 2>/dev/null)" ]; then
  echo "Assets not found or manifest missing. Compiling assets..."
  
  # Create builds directory
  mkdir -p /app/app/assets/builds
  
  # Build JavaScript and CSS
  yarn build
  yarn build:css
  
  # Generate manifest
  bundle exec rails assets:precompile
  
  echo "Assets compiled successfully"
else
  echo "Assets already compiled, skipping..."
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"