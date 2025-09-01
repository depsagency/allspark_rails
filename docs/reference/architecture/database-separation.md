# Database Separation Architecture

## Overview

Builder and Target containers use separate PostgreSQL databases to ensure complete data isolation between the Allspark UI and the development environment.

## Database Configuration

### PostgreSQL Container
- Single PostgreSQL instance with multiple databases
- Initialization script creates both databases on first startup
- Path: `/docker/init-db.sql`

### Databases
1. **allspark_builder** - Used by Builder container (port 3001)
   - Stores Allspark UI data (projects, users, settings)
   - Used by Builder and Builder-Sidekiq containers

2. **allspark_target** - Used by Target container (port 3000)
   - Stores development application data
   - Used by Target and Target-Sidekiq containers

## Container Configuration

```yaml
# Builder containers
builder:
  environment:
    DATABASE_URL: postgresql://postgres:password@db:5432/allspark_builder

builder-sidekiq:
  environment:
    DATABASE_URL: postgresql://postgres:password@db:5432/allspark_builder

# Target containers
target:
  environment:
    DATABASE_URL: postgresql://postgres:password@db:5432/allspark_target

target-sidekiq:
  environment:
    DATABASE_URL: postgresql://postgres:password@db:5432/allspark_target
```

## Benefits

1. **Data Isolation**: Changes in one environment don't affect the other
2. **Independent Development**: Target can have different schemas/data
3. **Clean Testing**: Target database can be reset without affecting Builder
4. **User Separation**: Users in Builder don't appear in Target

## Database Management

### Access databases directly:
```bash
# Connect to Builder database
docker exec -it allspark-db-1 psql -U postgres -d allspark_builder

# Connect to Target database
docker exec -it allspark-db-1 psql -U postgres -d allspark_target
```

### Reset databases:
```bash
# Stop containers and remove volumes
docker-compose down -v

# Start fresh (databases will be recreated)
docker-compose up -d
```

## Migration Note

When migrating from a shared database setup:
1. Stop all containers: `docker-compose down`
2. Remove database volume: `docker volume rm allspark_postgres_data`
3. Start containers: `docker-compose up -d`
4. Both databases will be created fresh with schema migrations