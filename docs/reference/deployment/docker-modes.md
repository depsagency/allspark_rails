# Docker Deployment Modes

Allspark supports two Docker deployment modes to suit different development needs.

## Overview

### Simple Mode (Default)
A single container running the complete Allspark application.

**Best for:**
- Solo developers
- Getting started quickly
- Simple projects
- Local development

**Architecture:**
```
┌─────────────────────────┐
│   Allspark Container    │
│     (Port 3000)         │
│                         │
│  - Rails Application    │
│  - App Builder UI       │
│  - Claude Code          │
│  - All Features         │
└─────────────────────────┘
```

### Dual-Container Mode (Advanced)
Separate Builder and Target containers for enhanced workflow.

**Best for:**
- Team development
- Complex projects
- Testing generated applications
- Isolating development environments

**Architecture:**
```
┌─────────────────────────┐     ┌─────────────────────────┐
│   Builder Container     │     │   Target Container      │
│     (Port 3001)         │     │     (Port 3000)         │
│                         │     │                         │
│  - Allspark UI          │────▶│  - Development Env      │
│  - Project Management   │     │  - Claude Code          │
│  - PRD/Task Generation  │     │  - Your Generated App   │
│  - Terminal to Target   │     │  - Isolated Workspace   │
└─────────────────────────┘     └─────────────────────────┘
```

## Quick Start

### Starting Simple Mode
```bash
# Default mode - just use docker-compose
docker-compose up -d

# Or use the convenience script
./bin/start-simple.sh
```

### Starting Dual-Container Mode
```bash
# Use the dual compose file
docker-compose -f docker-compose.dual.yml up -d

# Or use the convenience script
./bin/start-dual.sh
```

### Switching Between Modes
```bash
# Switch to simple mode
./bin/switch-mode.sh simple

# Switch to dual mode
./bin/switch-mode.sh dual

# Check current mode
./bin/switch-mode.sh status
```

## Mode Comparison

| Feature | Simple Mode | Dual-Container Mode |
|---------|-------------|-------------------|
| **Setup Complexity** | Easy | Moderate |
| **Resource Usage** | Lower | Higher |
| **Port** | 3000 | 3001 (Builder), 3000 (Target) |
| **Live Code Updates** | Yes | Builder only |
| **Isolation** | No | Yes |
| **Asset Precompilation** | Automatic | Automatic |
| **Best For** | Quick start, solo dev | Teams, testing, complex apps |

## Detailed Mode Descriptions

### Simple Mode Details

In simple mode, everything runs in a single container:

1. **Single Database**: Uses `allspark_development` database
2. **Live Mount**: Code changes reflect immediately
3. **Single Port**: Access everything at `http://localhost:3000`
4. **Unified Environment**: Builder and target are the same
5. **Asset Precompilation**: Automatically runs on first launch if assets don't exist

**When to use:**
- You're just getting started with Allspark
- You want to quickly generate a project
- You're working alone
- You don't need environment isolation

### Dual-Container Mode Details

In dual mode, Builder and Target are separated:

1. **Separate Databases**: 
   - Builder: `allspark_builder`
   - Target: `allspark_target`

2. **Volume Configuration**:
   - Builder: Live mount (`.:/app`)
   - Target: Named volume with code snapshot

3. **Port Separation**:
   - Builder UI: `http://localhost:3001`
   - Target App: `http://localhost:3000`

4. **Workflow**:
   - Create projects in Builder
   - Generate PRD, tasks, and prompts
   - Use terminal in Builder to access Target
   - Develop in Target with Claude Code

**When to use:**
- You want clean separation between builder and app
- You're testing generated applications
- You need multiple isolated environments
- You're working in a team

## Working with Dual-Container Mode

### Session Management
Both containers use different session cookies, allowing simultaneous login:
- Builder: `_allspark_builder_session`
- Target: `_allspark_target_session`

### Updating Target from Builder
When you make improvements in Builder that you want in Target:

```bash
# Use the update script
./bin/update-target.sh

# Or manually:
docker-compose -f docker-compose.dual.yml stop target target-sidekiq
docker-compose -f docker-compose.dual.yml rm -f target target-sidekiq
docker volume rm allspark_target_app
docker-compose -f docker-compose.dual.yml up -d target target-sidekiq
```

### Terminal Access
The Builder UI includes a terminal that connects to the Target container:
1. Navigate to your project in Builder
2. Use the terminal section
3. You're now in `/workspace` on the Target container

## Environment Variables

Both modes support the same environment variables. Key ones include:

```bash
# Simple mode (.env)
APP_NAME=MyApp
DATABASE_URL=postgresql://postgres:password@db:5432/allspark_development
REDIS_URL=redis://redis:6379/0

# Dual mode automatically sets CONTAINER_ROLE
CONTAINER_ROLE=builder  # or target
```

## Troubleshooting

### Asset Precompilation
Assets are automatically precompiled on container startup if they don't exist. You'll see:
```
🎨 Assets not found, precompiling...
```

To manually precompile assets:
```bash
docker-compose exec web rails assets:precompile
```

### Port Conflicts
If you get port already in use errors:
```bash
# Find what's using the port
lsof -i :3000
lsof -i :3001

# Or force stop all Allspark containers
docker-compose down
docker-compose -f docker-compose.dual.yml down
```

### Switching Modes
Always stop the current mode before switching:
```bash
# This is handled automatically by switch-mode.sh
./bin/switch-mode.sh dual
```

### Volume Issues
If you have volume permission issues:
```bash
# Reset volumes (warning: loses data)
docker volume prune
```

## Best Practices

1. **Start Simple**: Begin with simple mode and switch to dual when needed
2. **Commit Before Switching**: Always commit your changes before switching modes
3. **Use Scripts**: The provided scripts handle cleanup and setup correctly
4. **Check Status**: Run `./bin/switch-mode.sh status` to verify current mode

## Migration Between Modes

### From Simple to Dual
1. Stop simple mode: `docker-compose down`
2. Commit any changes: `git add . && git commit`
3. Start dual mode: `./bin/start-dual.sh`
4. Your code is now in both Builder and Target

### From Dual to Simple
1. Stop dual mode: `docker-compose -f docker-compose.dual.yml down`
2. If you made Target changes, copy them back to Builder first
3. Start simple mode: `./bin/start-simple.sh`