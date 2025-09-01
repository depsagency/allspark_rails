# Environment Variables Reference

This document provides a comprehensive reference for all environment variables used in the Allspark web-based development environment.

## Overview

Environment variables are used to configure both Builder and Target containers at runtime. Variables are organized by:
- **Container Role**: Which container uses the variable
- **Environment**: Development vs Production usage
- **Required vs Optional**: Whether the variable must be set

## Core Environment Variables

### Container Role Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `CONTAINER_ROLE` | Both | Yes | `target` | Determines container behavior: `builder` or `target` |

### Rails Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `RAILS_ENV` | Both | Yes | `development` | Rails environment: `production` for builder, `development` for target |
| `SECRET_KEY_BASE` | Builder | Yes (prod) | - | 128-character secret key for production (generate with `rails secret`) |
| `RAILS_LOG_LEVEL` | Both | No | `debug` | Log level: `debug`, `info`, `warn`, `error` |
| `RAILS_LOG_TO_STDOUT` | Both | No | `true` | Enable logging to STDOUT for Docker |
| `RAILS_SERVE_STATIC_FILES` | Builder | Yes (prod) | `false` | Serve static files in production |

### Database Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `DATABASE_URL` | Both | Yes | - | PostgreSQL connection string |
| `DATABASE_POOL` | Both | No | `5` | Database connection pool size |
| `DATABASE_TIMEOUT` | Both | No | `5000` | Database connection timeout (ms) |

**Database URL Patterns**:
- Builder: `postgresql://user:pass@db:5432/allspark_production`
- Target Template: `postgresql://user:pass@db:5432/allspark_target_template`
- Target Instance: `postgresql://user:pass@db:5432/allspark_target_<project_id>`

### Redis Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `REDIS_URL` | Both | Yes | - | Redis connection string |
| `REDIS_CACHE_URL` | Both | No | Same as REDIS_URL | Separate cache Redis instance |

**Redis URL Patterns**:
- Builder: `redis://redis:6379/0`
- Target: `redis://redis:6379/1`

### Application Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `APP_NAME` | Both | No | `Allspark` | Application name for branding |
| `APP_HOST` | Builder | No | `localhost` | Application hostname |
| `BUILDER_URL` | Builder | No | - | Full URL for builder (e.g., `https://builder.yourdomain.com`) |
| `TARGET_URL` | Builder | No | - | Full URL for target (e.g., `https://app.yourdomain.com`) |

### Docker Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `DOCKER_HOST` | Builder | Yes | `unix:///var/run/docker.sock` | Docker daemon connection |
| `DOCKER_API_VERSION` | Builder | No | Auto-detect | Docker API version to use |

### AI/LLM Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `LLM_PROVIDER` | Both | No | `openrouter` | Primary LLM provider: `openrouter`, `openai`, `claude`, `gemini` |
| `OPENROUTER_API_KEY` | Both | No* | - | OpenRouter API key (recommended for all models) |
| `OPENAI_API_KEY` | Both | No* | - | OpenAI API key (if using OpenAI directly) |
| `CLAUDE_API_KEY` | Both | No* | - | Anthropic Claude API key |
| `GEMINI_API_KEY` | Both | No* | - | Google Gemini API key |
| `LLM_FALLBACK_PROVIDERS` | Both | No | - | Comma-separated fallback providers |
| `LLM_CACHE_ENABLED` | Both | No | `true` | Enable LLM response caching |
| `LLM_TIMEOUT` | Both | No | `120` | LLM request timeout (seconds) |

*At least one LLM API key is required for AI features

### Claude Code Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `INIT_CLAUDE` | Target | No | `false` | Initialize Claude Code on container start |
| `CLAUDE_PROJECT_PATH` | Target | No | `/app` | Default project path for Claude |
| `CLAUDE_AUTO_START` | Target | No | `false` | Auto-start Claude session |

### Session Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `SESSION_TIMEOUT` | Both | No | `86400` | Session timeout in seconds (24 hours) |
| `CONTAINER_IDLE_TIMEOUT` | Target | No | `3600` | Idle timeout before container stops (1 hour) |

### Security Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `ALLOWED_HOSTS` | Builder | No | `*` | Comma-separated allowed hosts |
| `FORCE_SSL` | Builder | No | `false` | Force SSL in production |
| `SECURE_COOKIES` | Builder | No | `true` | Use secure cookies in production |

### Monitoring Configuration

| Variable | Container | Required | Default | Description |
|----------|-----------|----------|---------|-------------|
| `HEALTH_CHECK_PATH` | Both | No | `/health` | Health check endpoint path |
| `METRICS_ENABLED` | Both | No | `false` | Enable metrics collection |
| `SENTRY_DSN` | Both | No | - | Sentry error tracking DSN |

## Environment-Specific Variables

### Development Environment

```bash
# .env.development
CONTAINER_ROLE=target
RAILS_ENV=development
DATABASE_URL=postgresql://postgres:password@db:5432/allspark_development
REDIS_URL=redis://redis:6379/0
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-your-dev-key
```

### Production Environment - Builder

```bash
# .env.production (Builder)
CONTAINER_ROLE=builder
RAILS_ENV=production
SECRET_KEY_BASE=your-128-character-secret-key
DATABASE_URL=postgresql://postgres:strong-password@db:5432/allspark_production
REDIS_URL=redis://:redis-password@redis:6379/0
RAILS_SERVE_STATIC_FILES=true
DOCKER_HOST=unix:///var/run/docker.sock
OPENROUTER_API_KEY=sk-or-v1-your-prod-key
APP_NAME=Allspark
RAILS_LOG_LEVEL=info
BUILDER_URL=https://builder.yourdomain.com
TARGET_URL=https://app.yourdomain.com
ALLOWED_HOSTS=builder.yourdomain.com
FORCE_SSL=true
```

### Production Environment - Target

```bash
# Dynamic environment for Target containers
CONTAINER_ROLE=target
RAILS_ENV=development
PROJECT_ID=abc123
DATABASE_URL=postgresql://postgres:password@db:5432/allspark_target_abc123
REDIS_URL=redis://redis:6379/1
INIT_CLAUDE=true
CLAUDE_API_KEY=sk-ant-your-claude-key
CLAUDE_PROJECT_PATH=/app
SESSION_TIMEOUT=86400
CONTAINER_IDLE_TIMEOUT=3600
```

## Docker Compose Environment

### Service-Level Variables

```yaml
services:
  builder:
    environment:
      - CONTAINER_ROLE=builder
      - RAILS_ENV=${RAILS_ENV:-production}
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - DOCKER_HOST=unix:///var/run/docker.sock
    env_file:
      - .env.production

  target:
    environment:
      - CONTAINER_ROLE=target
      - RAILS_ENV=development
      - DATABASE_URL=${TARGET_DATABASE_URL}
      - REDIS_URL=${TARGET_REDIS_URL}
    env_file:
      - .env.target
```

## Variable Validation

### Required Variables Checklist

**Production Builder**:
- [ ] `SECRET_KEY_BASE` - Generated and secure
- [ ] `DATABASE_URL` - Production database connection
- [ ] `REDIS_URL` - Production Redis connection
- [ ] `DOCKER_HOST` - Docker socket access
- [ ] `RAILS_SERVE_STATIC_FILES=true`
- [ ] At least one LLM API key

**Production Target**:
- [ ] `PROJECT_ID` - Unique project identifier
- [ ] `DATABASE_URL` - Project-specific database
- [ ] `REDIS_URL` - Isolated Redis database
- [ ] `CLAUDE_API_KEY` - For Claude Code integration

### Validation Script

```bash
#!/bin/bash
# validate-env.sh

required_builder_vars=(
  "SECRET_KEY_BASE"
  "DATABASE_URL"
  "REDIS_URL"
  "DOCKER_HOST"
  "RAILS_SERVE_STATIC_FILES"
)

required_target_vars=(
  "PROJECT_ID"
  "DATABASE_URL"
  "REDIS_URL"
)

validate_env() {
  local role=$1
  local vars=()
  
  if [ "$role" = "builder" ]; then
    vars=("${required_builder_vars[@]}")
  else
    vars=("${required_target_vars[@]}")
  fi
  
  for var in "${vars[@]}"; do
    if [ -z "${!var}" ]; then
      echo "ERROR: Required variable $var is not set"
      exit 1
    fi
  done
  
  echo "All required variables for $role are set"
}

validate_env "${CONTAINER_ROLE:-target}"
```

## Best Practices

1. **Security**:
   - Never commit `.env` files to version control
   - Use strong, unique passwords for production
   - Rotate API keys regularly
   - Use separate API keys for development and production

2. **Organization**:
   - Keep development and production variables separate
   - Use `.env.example` as a template
   - Document any custom variables in this file
   - Group related variables together

3. **Defaults**:
   - Provide sensible defaults where possible
   - Make defaults safe (e.g., debug mode off in production)
   - Document when defaults are not suitable for production

4. **Validation**:
   - Validate required variables on startup
   - Provide clear error messages for missing variables
   - Use the validation script in deployment pipelines

## Troubleshooting

### Common Issues

1. **"Missing required environment variable"**
   - Check that all required variables are set
   - Ensure `.env` file is in the correct location
   - Verify variable names match exactly (case-sensitive)

2. **"Cannot connect to database"**
   - Verify DATABASE_URL format is correct
   - Check network connectivity between containers
   - Ensure database service is running

3. **"Docker socket permission denied"**
   - Check DOCKER_HOST is set correctly
   - Verify socket is mounted in container
   - Ensure user has permission to access socket

4. **"LLM provider not configured"**
   - Set at least one LLM API key
   - Verify LLM_PROVIDER matches available keys
   - Check API key format and validity