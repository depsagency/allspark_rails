# Docker Development and Deployment Guide

This guide covers Docker setup for both development and production environments.

## Development with Docker

### Quick Start
```bash
# Clone the repository
git clone <repository-url>
cd rails-template

# Copy environment file
cp .env.example .env

# Start all services
docker-compose up -d

# Setup database
docker-compose exec web rails db:setup

# Visit application
open http://localhost:3000
```

### Docker Compose Services

The development stack includes:
- **web**: Rails application server
- **postgres**: PostgreSQL database
- **redis**: Redis for caching and ActionCable
- **sidekiq**: Background job processor

### Common Docker Commands

#### Container Management
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart a specific service
docker-compose restart web

# View running containers
docker-compose ps

# View logs
docker-compose logs -f web
docker-compose logs -f sidekiq
```

#### Rails Commands
```bash
# Rails console
docker-compose exec web rails console

# Run migrations
docker-compose exec web rails db:migrate

# Run tests
docker-compose exec web rails test

# Install gems
docker-compose exec web bundle install

# Install npm packages
docker-compose exec web yarn install
```

#### Database Operations
```bash
# Create database
docker-compose exec web rails db:create

# Run migrations
docker-compose exec web rails db:migrate

# Seed database
docker-compose exec web rails db:seed

# Reset database
docker-compose exec web rails db:reset

# Database console
docker-compose exec postgres psql -U postgres -d rails_template_development
```

### Development Workflow

#### 1. Making Code Changes
Code changes are automatically synced via Docker volumes:
```yaml
volumes:
  - .:/app
  - bundle_cache:/usr/local/bundle
  - node_modules:/app/node_modules
```

#### 2. Adding Gems
```bash
# Add to Gemfile, then:
docker-compose exec web bundle install
docker-compose restart web
```

#### 3. Adding NPM Packages
```bash
# Add to package.json, then:
docker-compose exec web yarn install
docker-compose restart web
```

#### 4. Running Generators
```bash
# Generate a model
docker-compose exec web rails generate model Product name:string

# Generate a controller
docker-compose exec web rails generate controller Products
```

### Debugging in Docker

#### Accessing Shell
```bash
# Bash shell in web container
docker-compose exec web bash

# Rails console
docker-compose exec web rails console
```

#### Using Debugger
Add to your code:
```ruby
debugger
```

Then attach to the container:
```bash
docker attach $(docker-compose ps -q web)
```

#### Viewing Logs
```bash
# All logs
docker-compose logs -f

# Specific service
docker-compose logs -f web

# Last 100 lines
docker-compose logs --tail=100 web
```

### Docker Build Process

#### Rebuilding Images
```bash
# Rebuild after Dockerfile changes
docker-compose build

# Rebuild without cache
docker-compose build --no-cache

# Rebuild specific service
docker-compose build web
```

#### Cleaning Up
```bash
# Remove stopped containers
docker-compose rm

# Remove all containers and networks
docker-compose down

# Remove all containers, networks, and volumes
docker-compose down -v

# Clean up dangling images
docker image prune
```

## Production Docker Setup

### Production Dockerfile
The production Dockerfile uses multi-stage builds:

```dockerfile
# Stage 1: Build dependencies
FROM ruby:3.3-alpine AS builder
# Install build dependencies
# Bundle install

# Stage 2: Production image
FROM ruby:3.3-alpine
# Copy built artifacts
# Configure production environment
```

### Environment Variables
Required for production:
```bash
# Database
DATABASE_URL=postgresql://user:pass@db:5432/app_production

# Redis
REDIS_URL=redis://redis:6379/1

# Rails
RAILS_ENV=production
RAILS_MASTER_KEY=your-master-key
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Application
APP_NAME=YourApp
SECRET_KEY_BASE=your-secret-key
```

### Docker Compose Production
```yaml
version: '3.8'

services:
  web:
    build: .
    environment:
      - RAILS_ENV=production
    depends_on:
      - postgres
      - redis
    ports:
      - "3000:3000"
    
  sidekiq:
    build: .
    command: bundle exec sidekiq
    environment:
      - RAILS_ENV=production
    depends_on:
      - postgres
      - redis
```

### Building for Production
```bash
# Build production image
docker build -t myapp:latest .

# Tag for registry
docker tag myapp:latest registry.example.com/myapp:latest

# Push to registry
docker push registry.example.com/myapp:latest
```

## Docker Deployment Options

### Option 1: Docker Swarm
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.prod.yml myapp

# Scale service
docker service scale myapp_web=3
```

### Option 2: Kubernetes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rails
  template:
    metadata:
      labels:
        app: rails
    spec:
      containers:
      - name: web
        image: myapp:latest
        ports:
        - containerPort: 3000
```

### Option 3: AWS ECS
```bash
# Build and push to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URL
docker build -t myapp .
docker tag myapp:latest $ECR_URL/myapp:latest
docker push $ECR_URL/myapp:latest

# Update service
aws ecs update-service --cluster production --service myapp --force-new-deployment
```

## Health Checks

### Docker Health Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

### Application Health Endpoint
```ruby
# config/routes.rb
get '/health', to: 'health#show'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    render json: {
      status: 'ok',
      database: database_healthy?,
      redis: redis_healthy?,
      sidekiq: sidekiq_healthy?
    }
  end
end
```

## Troubleshooting

### Common Issues

#### 1. Port Already in Use
```bash
# Find process using port
lsof -i :3000

# Or change port in docker-compose.yml
ports:
  - "3001:3000"
```

#### 2. Permission Issues
```bash
# Fix ownership
docker-compose exec web chown -R $(id -u):$(id -g) .

# Or run as root temporarily
docker-compose exec -u root web bash
```

#### 3. Bundle Install Failures
```bash
# Clear bundle cache
docker-compose down -v
docker-compose build --no-cache
docker-compose up
```

#### 4. Database Connection Issues
```bash
# Check database is running
docker-compose ps postgres

# Check logs
docker-compose logs postgres

# Verify connection
docker-compose exec web rails db:version
```

### Performance Optimization

#### 1. Use Volume Caching
```yaml
volumes:
  - .:/app:cached  # For macOS
```

#### 2. Optimize Dockerfile
- Use multi-stage builds
- Minimize layers
- Cache dependencies
- Remove unnecessary files

#### 3. Resource Limits
```yaml
services:
  web:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

## Security Best Practices

1. **Don't store secrets in images**
   - Use environment variables
   - Use Docker secrets
   - Use external secret management

2. **Run as non-root user**
   ```dockerfile
   RUN adduser -D myapp
   USER myapp
   ```

3. **Minimal base images**
   - Use alpine variants
   - Remove unnecessary packages

4. **Scan for vulnerabilities**
   ```bash
   docker scan myapp:latest
   ```

5. **Network isolation**
   - Use custom networks
   - Limit exposed ports

## Monitoring

### Container Metrics
```bash
# CPU and memory usage
docker stats

# Detailed inspection
docker inspect <container_id>
```

### Logging
```bash
# Configure logging driver
docker run --log-driver=json-file --log-opt max-size=10m myapp

# Centralized logging
docker run --log-driver=syslog --log-opt syslog-address=udp://logserver:514 myapp
```

## Backup and Recovery

### Database Backup
```bash
# Backup
docker-compose exec postgres pg_dump -U postgres rails_template_production > backup.sql

# Restore
docker-compose exec -T postgres psql -U postgres rails_template_production < backup.sql
```

### Volume Backup
```bash
# Backup volumes
docker run --rm -v myapp_data:/data -v $(pwd):/backup alpine tar czf /backup/data.tar.gz /data

# Restore volumes
docker run --rm -v myapp_data:/data -v $(pwd):/backup alpine tar xzf /backup/data.tar.gz -C /
```