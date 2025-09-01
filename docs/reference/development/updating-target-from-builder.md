# Updating Target Container from Builder Changes

## Overview

When you make improvements, bug fixes, or add features in the Builder container, you need to propagate these changes to the Target container. This document describes the recommended process.

## Architecture Reminder

- **Builder Container**: Uses live mount (`.:/app`) - changes are immediately reflected
- **Target Container**: Uses named volume (`target_app:/app`) - has its own isolated copy

## Standard Update Process (Option 1: Rebuild)

This is the recommended approach for most updates, especially feature releases and significant changes.

### Steps

1. **Make and Test Changes in Builder**
   ```bash
   # Your changes are automatically reflected in Builder due to live mount
   # Access Builder UI at http://localhost:3001
   # Test thoroughly
   ```

2. **Commit Changes to Git**
   ```bash
   # Check what has changed
   git status
   
   # Add and commit changes
   git add .
   git commit -m "feat: describe your changes"
   ```

3. **Stop Target Containers**
   ```bash
   docker-compose stop target target-sidekiq
   ```

4. **Rebuild Target Container Images**
   ```bash
   # Rebuild with latest code
   docker-compose build target target-sidekiq
   ```

5. **Recreate Target Containers**
   ```bash
   # Remove old containers and volumes
   docker-compose rm -f target target-sidekiq
   docker volume rm allspark_target_app
   
   # Start fresh containers
   docker-compose up -d target target-sidekiq
   ```

6. **Verify Update**
   ```bash
   # Check Target is running with new code
   docker logs allspark-target-1
   
   # Access Target at http://localhost:3000
   ```

## What This Process Does

1. **Preserves Builder State**: Builder container continues running with live code
2. **Clean Target Update**: Target gets fresh copy of all code changes
3. **Database Separation**: Target's database remains separate (allspark_target)
4. **Fresh Start**: Target volume is recreated, ensuring clean state

## When to Use This Process

- **Feature Releases**: When adding new functionality
- **Major Bug Fixes**: When fixing core issues
- **Dependency Updates**: When updating gems or packages
- **Configuration Changes**: When modifying initializers or config

## Alternative: Quick Hotfix (For Urgent Fixes)

For single-file urgent fixes, you can use the selective sync approach:

```bash
# Copy specific file from Builder to Target via workspace
docker exec allspark-builder-1 cp /app/path/to/fixed_file.rb /workspace/path/to/fixed_file.rb

# Restart Target if needed
docker-compose restart target
```

## Important Notes

1. **Target Data Loss**: Rebuilding Target removes any data in Target's volume
2. **Database Persists**: Target's PostgreSQL database (allspark_target) is preserved
3. **Session Separation**: Users remain logged in separately due to different cookies
4. **Port Access**: Ensure ports 3000 (Target) and 3001 (Builder) remain available

## Automation Script

Save this as `bin/update-target.sh` for convenience:

```bash
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
```

Make it executable: `chmod +x bin/update-target.sh`
Then run: `./bin/update-target.sh`