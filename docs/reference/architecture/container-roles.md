# Container Roles and Services

## Overview

The Allspark dual-container architecture runs two separate Rails applications:

### Builder Container (Port 3001)
- **Role**: Allspark UI and management interface
- **Service**: Rails server on port 3001
- **Database**: Uses allspark_development database
- **Purpose**: Project management, terminal access, Claude Code integration
- **Volume**: Live mount from host for active development

### Target Container (Port 3000)
- **Role**: Development environment for user applications
- **Service**: Rails server on port 3000
- **Database**: Uses allspark_development database (shared)
- **Purpose**: Run and test user's application code
- **Volume**: Isolated named volume with initial code from image

## Service Ports

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Allspark UI | Builder | 3001 | Project management interface |
| User Application | Target | 3000 | Development application |
| PostgreSQL | db | 5432 | Shared database |
| Redis | redis | 6379 | Shared cache/pubsub |

## Container Communication

- **Terminal Access**: Builder connects to Target via `docker exec`
- **File Access**: Builder mounts Target's `/app` as `/workspace`
- **Database**: Both containers share the same PostgreSQL instance
- **Redis**: Both containers share the same Redis instance

## Sidekiq Workers

### Builder Sidekiq
- Processes Builder-specific jobs
- Queues: `builder_default`, `builder_ai`, `builder_notifications`

### Target Sidekiq
- Processes Target-specific jobs
- Queues: `target_development`, `target_claude`, `target_files`

## Starting Services

All services start automatically when containers are launched:
```bash
docker-compose up -d
```

No manual intervention required - both Rails servers start automatically.