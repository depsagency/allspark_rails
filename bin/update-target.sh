#!/bin/bash
echo "🔄 Updating Target container with latest Builder changes..."

# Ensure we're in the project root
cd "$(dirname "$0")/.."

echo "📦 Building Target containers..."
docker-compose build target target-sidekiq

echo "🛑 Stopping Target containers..."
docker-compose stop target target-sidekiq
docker-compose rm -f target target-sidekiq

echo "🗑️  Removing Target volume..."
docker volume rm allspark_target_app 2>/dev/null || true

echo "🚀 Starting Target containers..."
docker-compose up -d target target-sidekiq

echo "✅ Target updated! Access at http://localhost:3000"