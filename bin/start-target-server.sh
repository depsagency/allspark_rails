#!/bin/bash

# Start the target Rails server for DevTools testing
# This runs inside the Docker container

cd /app/allspark-projects/target

# Remove any existing server pid
rm -f tmp/pids/server.pid

# Ensure database exists
bundle exec rails db:prepare 2>/dev/null || true

# Start Rails server on port 3001
echo "Starting target Rails server on port 3001..."
bundle exec rails server -b 0.0.0.0 -p 3001