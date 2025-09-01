#!/bin/bash
set -e

# Entrypoint script for Rails application container
# Handles setup for both web server and sidekiq

echo "🚀 Starting Rails container"

# Determine if we're running Sidekiq based on the command
if [[ "$@" == *"sidekiq"* ]]; then
    CONTAINER_TYPE="sidekiq"
else
    CONTAINER_TYPE="web"
fi

# Set development environment
export RAILS_ENV=${RAILS_ENV:-development}

# Setup bundle path
export BUNDLE_PATH=/usr/local/bundle
export GEM_HOME=/usr/local/bundle
export PATH=$GEM_HOME/bin:$PATH

# In development, ensure bundle is not frozen
if [ "$RAILS_ENV" == "development" ]; then
  bundle config set frozen false
fi

# Check if bundle install is needed
# If gems were pre-installed during build, this should be very fast
if [ -f "/usr/local/bundle/.preinstalled" ]; then
  echo "✅ Using pre-installed gems from Docker image"
  # Just verify everything is in sync
  bundle check >/dev/null 2>&1 || bundle install --local --jobs 4
elif ! bundle check >/dev/null 2>&1; then
  echo "📦 Installing missing gems..."
  bundle install --jobs 4 --retry 3
else
  echo "✅ All gems already installed"
fi

if [ "$CONTAINER_TYPE" == "web" ]; then
    # Web server specific setup
    
    # Remove stale PID file if it exists
    rm -f tmp/pids/server.pid
    
    # Run database setup if needed
    if [ "$RAILS_ENV" != "test" ]; then
      echo "🗃️  Setting up database..."
      bundle exec rails db:prepare || echo "Database setup continuing..."
    fi
    
    # Check and compile assets if needed
    if [ ! -d "public/assets" ] || [ -z "$(ls -A public/assets 2>/dev/null)" ]; then
      echo "🎨 Assets not found, precompiling..."
      bundle exec rails assets:precompile || echo "Asset compilation failed but continuing..."
    else
      echo "✅ Assets already compiled"
    fi
    
    # Start Rails server
    echo "🌐 Starting Rails server on port 3000..."
    exec bundle exec rails server -b 0.0.0.0 -p 3000
else
    # Sidekiq specific setup
    echo "⚙️  Starting Sidekiq background job processor..."
    
    # Start Sidekiq with default queues
    echo "🔄 Starting Sidekiq"
    exec "$@"
fi