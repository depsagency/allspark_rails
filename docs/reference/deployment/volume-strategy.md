# Volume Strategy and Data Persistence

This document outlines the volume architecture, backup strategies, and data persistence approach for the Allspark web-based development environment.

## Volume Architecture Overview

The Allspark platform uses Docker volumes to persist data across container restarts and enable data sharing between containers. Volumes are organized by purpose and lifecycle.

## Volume Types and Purposes

### 1. Database Volumes

**Volume**: `postgres-data`
- **Purpose**: PostgreSQL database files
- **Persistence**: Critical - contains all application data
- **Backup Priority**: Highest
- **Size Estimate**: 1-50GB depending on usage

**Contents**:
- `allspark_production` - Builder application data
- `allspark_target_template` - Clean template for new projects
- `allspark_target_*` - Individual project databases

### 2. Redis Volumes

**Volume**: `redis-data`
- **Purpose**: Redis persistence files
- **Persistence**: Important - contains cache and session data
- **Backup Priority**: Medium
- **Size Estimate**: 100MB-1GB

**Contents**:
- Session data
- ActionCable subscriptions
- Cache entries
- Background job queues

### 3. Application Storage Volumes

**Volume**: `builder-data`
- **Purpose**: Builder application file storage
- **Persistence**: Critical - user uploads and generated files
- **Backup Priority**: High
- **Size Estimate**: Variable based on usage

**Contents**:
- User uploads
- Generated documentation
- Export files
- Temporary processing files

### 4. Workspace Volumes

**Volume**: `target-workspaces`
- **Purpose**: Shared workspace for target containers
- **Persistence**: Important - active development files
- **Backup Priority**: Medium
- **Size Estimate**: Variable, typically 10-100GB

**Structure**:
```
target-workspaces/
├── project-abc123/
│   ├── app/
│   ├── config/
│   └── ...
├── project-def456/
│   └── ...
└── templates/
    └── base/
```

### 5. SSH Keys Volume

**Volume**: `shared-ssh-keys`
- **Purpose**: SSH keys for Git operations
- **Persistence**: Important - deployment keys
- **Backup Priority**: High
- **Size Estimate**: < 1MB
- **Security**: Read-only mount in target containers

### 6. Log Volumes

**Volume**: `log-data`
- **Purpose**: Centralized application logs
- **Persistence**: Temporary - rotate regularly
- **Backup Priority**: Low
- **Size Estimate**: 1-10GB with rotation

## Docker Compose Volume Configuration

```yaml
# docker-compose.yml
version: '3.8'

volumes:
  # Persistent data volumes
  postgres-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /var/lib/allspark/postgres

  redis-data:
    driver: local

  # Application volumes
  builder-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /var/lib/allspark/builder-data

  target-workspaces:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /var/lib/allspark/workspaces

  # Shared configuration
  shared-ssh-keys:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /var/lib/allspark/ssh-keys

  # Temporary volumes
  log-data:
    driver: local

services:
  builder:
    volumes:
      - builder-data:/app/storage
      - shared-ssh-keys:/ssh-keys:ro
      - target-workspaces:/workspaces
      - /var/run/docker.sock:/var/run/docker.sock
      - log-data:/app/log

  target:
    volumes:
      - target-workspaces:/workspace
      - shared-ssh-keys:/ssh-keys:ro
      - log-data:/app/log
```

## Backup Strategy

### Automated Backup Schedule

```bash
# /etc/cron.d/allspark-backup
# Daily backups at 2 AM
0 2 * * * root /opt/allspark/deploy/backup.sh daily

# Weekly full backup on Sunday at 3 AM
0 3 * * 0 root /opt/allspark/deploy/backup.sh weekly

# Monthly archive on 1st at 4 AM
0 4 1 * * root /opt/allspark/deploy/backup.sh monthly
```

### Backup Script

```bash
#!/bin/bash
# /opt/allspark/deploy/backup.sh

set -e

BACKUP_TYPE=${1:-daily}
BACKUP_ROOT="/backups/allspark"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_TYPE/$DATE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to backup a volume
backup_volume() {
    local volume_name=$1
    local backup_name=$2
    
    echo "Backing up volume: $volume_name"
    
    # Create temporary container to access volume
    docker run --rm \
        -v "${volume_name}:/source:ro" \
        -v "${BACKUP_DIR}:/backup" \
        alpine \
        tar czf "/backup/${backup_name}.tar.gz" -C /source .
}

# Function to backup database
backup_database() {
    echo "Backing up PostgreSQL databases"
    
    # Backup all databases
    docker-compose exec -T db pg_dumpall -U postgres | \
        gzip > "${BACKUP_DIR}/postgres_all.sql.gz"
    
    # Individual database backups
    for db in allspark_production allspark_target_template; do
        docker-compose exec -T db pg_dump -U postgres "$db" | \
            gzip > "${BACKUP_DIR}/${db}.sql.gz"
    done
}

# Stop non-critical services during backup
echo "Preparing for backup..."
docker-compose stop target || true

# Perform backups
backup_database
backup_volume "builder-data" "builder-data"
backup_volume "target-workspaces" "workspaces"
backup_volume "shared-ssh-keys" "ssh-keys"
backup_volume "redis-data" "redis"

# Restart services
docker-compose start target || true

# Create backup manifest
cat > "${BACKUP_DIR}/manifest.json" <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "type": "$BACKUP_TYPE",
    "volumes": [
        "builder-data",
        "target-workspaces",
        "shared-ssh-keys",
        "redis-data"
    ],
    "databases": [
        "allspark_production",
        "allspark_target_template"
    ]
}
EOF

# Cleanup old backups
case $BACKUP_TYPE in
    daily)
        find "$BACKUP_ROOT/daily" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
        ;;
    weekly)
        find "$BACKUP_ROOT/weekly" -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true
        ;;
    monthly)
        find "$BACKUP_ROOT/monthly" -type d -mtime +365 -exec rm -rf {} + 2>/dev/null || true
        ;;
esac

echo "Backup completed: $BACKUP_DIR"
```

### Restore Procedures

```bash
#!/bin/bash
# /opt/allspark/deploy/restore.sh

set -e

BACKUP_PATH=$1

if [ -z "$BACKUP_PATH" ]; then
    echo "Usage: $0 <backup-path>"
    exit 1
fi

if [ ! -d "$BACKUP_PATH" ]; then
    echo "Backup path does not exist: $BACKUP_PATH"
    exit 1
fi

echo "WARNING: This will restore from backup: $BACKUP_PATH"
echo "All current data will be overwritten!"
read -p "Continue? (yes/no) " -r
if [[ ! $REPLY =~ ^yes$ ]]; then
    exit 1
fi

# Stop all services
echo "Stopping services..."
docker-compose down

# Restore database
echo "Restoring PostgreSQL databases..."
docker-compose up -d db
sleep 10

# Drop existing databases
docker-compose exec -T db psql -U postgres <<EOF
DROP DATABASE IF EXISTS allspark_production;
DROP DATABASE IF EXISTS allspark_target_template;
EOF

# Restore from backup
gunzip -c "$BACKUP_PATH/postgres_all.sql.gz" | \
    docker-compose exec -T db psql -U postgres

# Restore volumes
restore_volume() {
    local volume_name=$1
    local backup_file=$2
    
    echo "Restoring volume: $volume_name"
    
    # Clear existing volume
    docker volume rm -f "allspark_${volume_name}" || true
    docker volume create "allspark_${volume_name}"
    
    # Restore from backup
    docker run --rm \
        -v "allspark_${volume_name}:/target" \
        -v "${BACKUP_PATH}:/backup:ro" \
        alpine \
        tar xzf "/backup/${backup_file}" -C /target
}

restore_volume "builder-data" "builder-data.tar.gz"
restore_volume "target-workspaces" "workspaces.tar.gz"
restore_volume "shared-ssh-keys" "ssh-keys.tar.gz"
restore_volume "redis-data" "redis.tar.gz"

# Start services
echo "Starting services..."
docker-compose up -d

echo "Restore completed from: $BACKUP_PATH"
```

## Volume Migration

### Migrating to Larger Storage

```bash
#!/bin/bash
# migrate-volume.sh

# Stop services
docker-compose down

# Create new volume location
mkdir -p /new-storage/allspark

# Copy data
rsync -avP /var/lib/allspark/ /new-storage/allspark/

# Update docker-compose.yml volumes
# Update device paths to point to /new-storage/allspark

# Restart services
docker-compose up -d
```

### Migrating to External Storage

For production deployments, consider:

1. **DigitalOcean Volumes**: Attach block storage for data volumes
2. **NFS Mounts**: For shared workspace access across multiple hosts
3. **Object Storage**: For backup archives (DigitalOcean Spaces, AWS S3)

## Performance Optimization

### Volume Driver Options

```yaml
volumes:
  postgres-data:
    driver: local
    driver_opts:
      type: ext4
      o: "noatime,nodiratime"
```

### SSD vs HDD Placement

**SSD Recommended**:
- `postgres-data` - Database requires fast I/O
- `redis-data` - In-memory database persistence
- `builder-data` - Frequent file operations

**HDD Acceptable**:
- `target-workspaces` - Large storage, sequential access
- `log-data` - Write-once, sequential
- Backup storage - Archival purposes

## Monitoring and Maintenance

### Volume Usage Monitoring

```bash
#!/bin/bash
# monitor-volumes.sh

echo "=== Docker Volume Usage ==="
docker system df -v

echo -e "\n=== Host Filesystem Usage ==="
df -h /var/lib/allspark/*

echo -e "\n=== Volume Details ==="
for vol in $(docker volume ls -q | grep allspark); do
    echo "Volume: $vol"
    docker run --rm -v "$vol:/data:ro" alpine du -sh /data
done
```

### Cleanup Procedures

```bash
# Remove unused volumes
docker volume prune -f

# Clean build cache
docker builder prune -f

# Remove old target workspaces
find /var/lib/allspark/workspaces -type d -name "project-*" -mtime +30 -exec rm -rf {} +

# Vacuum PostgreSQL
docker-compose exec db vacuumdb -U postgres -a -z
```

## Security Considerations

### Volume Permissions

```bash
# Set proper ownership
chown -R 1000:1000 /var/lib/allspark/builder-data
chown -R 1000:1000 /var/lib/allspark/workspaces
chmod 700 /var/lib/allspark/ssh-keys

# Restrict Docker socket access
chmod 660 /var/run/docker.sock
```

### Encryption at Rest

For sensitive data:

```bash
# Create encrypted volume
cryptsetup luksFormat /dev/vdb
cryptsetup open /dev/vdb allspark-encrypted

# Create filesystem
mkfs.ext4 /dev/mapper/allspark-encrypted

# Mount encrypted volume
mount /dev/mapper/allspark-encrypted /var/lib/allspark
```

### Backup Encryption

```bash
# Encrypt backup before storage
gpg --symmetric --cipher-algo AES256 backup.tar.gz

# Decrypt for restore
gpg --decrypt backup.tar.gz.gpg > backup.tar.gz
```

## Disaster Recovery

### Recovery Time Objectives

- **Database**: < 1 hour (from hourly snapshots)
- **Application Files**: < 2 hours (from daily backups)
- **Workspaces**: < 4 hours (from daily backups)
- **Full System**: < 8 hours (complete restore)

### Recovery Procedures

1. **Provision new infrastructure**
2. **Restore volumes from backup**
3. **Verify database integrity**
4. **Test application functionality**
5. **Restore workspaces for active projects**
6. **Notify users of restoration**

## Volume Best Practices

1. **Regular Backups**: Automate daily backups
2. **Test Restores**: Monthly restore drills
3. **Monitor Usage**: Alert on 80% capacity
4. **Clean Regularly**: Remove orphaned data
5. **Document Changes**: Track volume modifications
6. **Separate Concerns**: One purpose per volume
7. **Plan Growth**: Size volumes for 2x expected usage
8. **Secure Access**: Minimum required permissions