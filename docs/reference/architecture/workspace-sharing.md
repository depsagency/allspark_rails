# Workspace Sharing Architecture

## Overview

The Allspark dual-container architecture provides isolated environments for Builder and Target containers while allowing Claude Code to modify the Target's application through a shared workspace.

## Volume Configuration

### Target Container
- **Application Directory**: `/app` - Named volume with code from Docker image
- **Working Directory**: `/app` - Isolated development environment
- **Initial State**: Contains full application code copied during build

### Builder Container
- **Allspark Code**: `/app` - Live mount from host for UI development
- **Workspace Access**: `/workspace` - Mounted view of Target's `/app` volume
- **Access Mode**: Read-write to allow Claude Code modifications

## Docker Compose Configuration

```yaml
services:
  builder:
    volumes:
      - .:/app                    # Live mount for Allspark UI development
      - target_app:/workspace     # Access to Target's /app directory
      - /var/run/docker.sock:/var/run/docker.sock
  
  target:
    volumes:
      - target_app:/app           # Named volume with initial code from image
      - workspace_shared:/app/workspace  # Legacy workspace support

volumes:
  target_app:      # Isolated volume for Target's application
  workspace_shared:  # Legacy shared workspace
```

## How It Works

1. **Container Initialization**
   - **Builder**: Starts with live mount of host Allspark code in `/app`
   - **Target**: Starts with copy of application code from Docker image in `/app`
   - Each container has independent `/app` directories

2. **Builder Access to Target**
   - Builder mounts Target's `/app` volume as `/workspace`
   - Claude Code in Builder can read/write files in `/workspace`
   - Changes in `/workspace` immediately reflect in Target's `/app`

3. **Terminal Connection**
   - Terminal connects to Target container via Docker exec
   - Default working directory is Target's `/app`
   - Claude Code operates on Target's isolated application

## Benefits

- **Isolation**: Builder and Target have separate `/app` directories
- **Direct Code Modification**: Claude Code can modify Target via `/workspace`
- **Live Development**: Builder retains live mount for Allspark UI development
- **Persistent Development**: Target's code persists in named volume
- **Initial Code**: Target starts with full application code, not empty

## Usage Example

1. Start containers: `docker-compose up`
2. Access Builder UI: http://localhost:3001
3. Open terminal to Target container
4. Claude Code can modify files in `/workspace` (Builder's view)
5. Changes appear in Target's `/app` directory
6. Application runs with live code changes

## Migration from Previous Architecture

The previous architecture used an empty shared workspace directory. The new architecture:
- Mounts Target's actual `/app` directory as Builder's `/workspace`
- Maintains backward compatibility with `/app/workspace` directory
- Allows Claude Code to work on real application code