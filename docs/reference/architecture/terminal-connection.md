# Terminal Connection Architecture

## Overview

The terminal in Allspark's UI connects to the **Builder container** and operates in the `/workspace` directory, which provides access to the Target container's application files.

## Connection Details

### Container
- **Connected to**: Builder container (allspark-builder-1)
- **NOT connected to**: Target container
- **Reason**: Builder container has Claude Code and development tools

### Working Directory
- **Default path**: `/workspace`
- **What it shows**: Target container's `/app` directory contents
- **Access mode**: Read-write (can modify Target's files)

## How It Works

1. **Terminal Service** (`app/services/terminal_service.rb`):
   - Finds the Builder container using `find_builder_container`
   - Executes bash in Builder container
   - Changes directory to `/workspace`

2. **Volume Mounting**:
   ```yaml
   builder:
     volumes:
       - target_app:/workspace  # Target's /app mounted here
   ```

3. **User Experience**:
   - Terminal shows "Builder Container" badge
   - Working in `/workspace` modifies Target's application
   - Claude Code can be run directly from this terminal

## Benefits

- **Claude Code Access**: Builder has Claude Code CLI installed
- **File Modifications**: Changes in `/workspace` affect Target's running application
- **Development Tools**: Access to all tools in Builder container
- **Clear Context**: UI shows which container you're connected to

## Terminal Commands

When in the terminal, you're in the Builder container:
```bash
# You're here
pwd  # Shows: /workspace

# This is Target's application code
ls   # Shows Target's /app contents

# Claude Code works here
claude --help

# Modifications affect Target
echo "test" > test.txt  # Creates file in Target's /app
```