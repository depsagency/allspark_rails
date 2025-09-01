#!/bin/bash

# Script to backup an AllSpark instance
# Usage: ./bin/backup-instance.sh <instance_slug>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if instance slug is provided
if [ -z "$1" ]; then
  echo -e "${RED}Error: Instance slug is required${NC}"
  echo "Usage: $0 <instance_slug>"
  exit 1
fi

INSTANCE_SLUG=$1
ALLSPARK_ROOT=$(dirname "$(dirname "$(readlink -f "$0")")")
INSTANCE_DIR="${ALLSPARK_ROOT}/instances/${INSTANCE_SLUG}"
BACKUP_DIR="${ALLSPARK_ROOT}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${INSTANCE_SLUG}_backup_${TIMESTAMP}"

# Check if instance directory exists
if [ ! -d "${INSTANCE_DIR}" ]; then
  echo -e "${RED}Error: Instance '${INSTANCE_SLUG}' not found at ${INSTANCE_DIR}${NC}"
  exit 1
fi

echo -e "${BLUE}Creating backup for instance: ${INSTANCE_SLUG}${NC}"

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Change to instance directory
cd "${INSTANCE_DIR}/allspark"

# Stop containers to ensure data consistency
echo -e "${YELLOW}Stopping containers for consistent backup...${NC}"
docker-compose stop

# Backup database
echo -e "${YELLOW}Backing up database...${NC}"
docker-compose run --rm postgres pg_dump -U postgres -d "allspark_${INSTANCE_SLUG}_development" > \
  "${BACKUP_DIR}/${BACKUP_NAME}/database.sql"

# Backup volumes
echo -e "${YELLOW}Backing up Docker volumes...${NC}"
docker run --rm \
  -v "${INSTANCE_SLUG}_postgres_data:/source:ro" \
  -v "${BACKUP_DIR}/${BACKUP_NAME}:/backup" \
  alpine tar -czf /backup/postgres_data.tar.gz -C /source .

docker run --rm \
  -v "${INSTANCE_SLUG}_redis_data:/source:ro" \
  -v "${BACKUP_DIR}/${BACKUP_NAME}:/backup" \
  alpine tar -czf /backup/redis_data.tar.gz -C /source .

# Backup configuration files
echo -e "${YELLOW}Backing up configuration...${NC}"
cp "${INSTANCE_DIR}/allspark/.env" "${BACKUP_DIR}/${BACKUP_NAME}/" || true
cp "${INSTANCE_DIR}/allspark/docker-compose.override.yml" "${BACKUP_DIR}/${BACKUP_NAME}/" || true

# Backup uploaded files (if using local storage)
if [ -d "${INSTANCE_DIR}/allspark/storage" ]; then
  echo -e "${YELLOW}Backing up uploaded files...${NC}"
  tar -czf "${BACKUP_DIR}/${BACKUP_NAME}/storage.tar.gz" -C "${INSTANCE_DIR}/allspark" storage
fi

# Create backup metadata
echo -e "${YELLOW}Creating backup metadata...${NC}"
cat > "${BACKUP_DIR}/${BACKUP_NAME}/backup_info.json" << EOF
{
  "instance_slug": "${INSTANCE_SLUG}",
  "backup_timestamp": "${TIMESTAMP}",
  "backup_date": "$(date)",
  "backup_version": "1.0",
  "files": [
    "database.sql",
    "postgres_data.tar.gz",
    "redis_data.tar.gz",
    ".env",
    "docker-compose.override.yml"
  ]
}
EOF

# Create compressed archive
echo -e "${YELLOW}Creating compressed backup archive...${NC}"
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"

# Restart containers
echo -e "${YELLOW}Restarting containers...${NC}"
cd "${INSTANCE_DIR}/allspark"
docker-compose start

echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "Backup saved to: ${BLUE}${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"
echo -e "Size: $(du -h ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz | cut -f1)"