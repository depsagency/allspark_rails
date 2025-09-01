#!/bin/bash

# Script to restore an AllSpark instance from backup
# Usage: ./bin/restore-instance.sh <backup_file> [new_instance_slug]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if backup file is provided
if [ -z "$1" ]; then
  echo -e "${RED}Error: Backup file is required${NC}"
  echo "Usage: $0 <backup_file> [new_instance_slug]"
  exit 1
fi

BACKUP_FILE=$1
NEW_INSTANCE_SLUG=$2
ALLSPARK_ROOT=$(dirname "$(dirname "$(readlink -f "$0")")")
TEMP_DIR="/tmp/allspark_restore_$$"

# Check if backup file exists
if [ ! -f "${BACKUP_FILE}" ]; then
  echo -e "${RED}Error: Backup file '${BACKUP_FILE}' not found${NC}"
  exit 1
fi

echo -e "${BLUE}Restoring instance from backup: ${BACKUP_FILE}${NC}"

# Extract backup
echo -e "${YELLOW}Extracting backup...${NC}"
mkdir -p "${TEMP_DIR}"
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Find the backup directory
BACKUP_DIR=$(find "${TEMP_DIR}" -maxdepth 1 -type d | grep -v "^${TEMP_DIR}$" | head -1)

# Read backup metadata
if [ -f "${BACKUP_DIR}/backup_info.json" ]; then
  ORIGINAL_SLUG=$(grep -o '"instance_slug": "[^"]*' "${BACKUP_DIR}/backup_info.json" | cut -d'"' -f4)
  echo -e "${BLUE}Original instance slug: ${ORIGINAL_SLUG}${NC}"
else
  echo -e "${YELLOW}Warning: No backup metadata found${NC}"
  ORIGINAL_SLUG="unknown"
fi

# Determine instance slug
INSTANCE_SLUG=${NEW_INSTANCE_SLUG:-$ORIGINAL_SLUG}
echo -e "${BLUE}Restoring as instance: ${INSTANCE_SLUG}${NC}"

# Create instance using create-instance.sh
echo -e "${YELLOW}Creating new instance structure...${NC}"
"${ALLSPARK_ROOT}/bin/create-instance.sh" "${INSTANCE_SLUG}"

# Stop the newly created instance
echo -e "${YELLOW}Stopping instance for restore...${NC}"
"${ALLSPARK_ROOT}/bin/stop-instance.sh" "${INSTANCE_SLUG}"

# Change to instance directory
INSTANCE_DIR="${ALLSPARK_ROOT}/instances/${INSTANCE_SLUG}"
cd "${INSTANCE_DIR}/allspark"

# Restore configuration
echo -e "${YELLOW}Restoring configuration...${NC}"
if [ -f "${BACKUP_DIR}/.env" ]; then
  cp "${BACKUP_DIR}/.env" .env
  # Update instance-specific variables if using new slug
  if [ "${INSTANCE_SLUG}" != "${ORIGINAL_SLUG}" ]; then
    sed -i.bak "s/${ORIGINAL_SLUG}/${INSTANCE_SLUG}/g" .env
    rm .env.bak
  fi
fi

# Restore docker-compose override
if [ -f "${BACKUP_DIR}/docker-compose.override.yml" ]; then
  cp "${BACKUP_DIR}/docker-compose.override.yml" docker-compose.override.yml
  # Update instance-specific references if using new slug
  if [ "${INSTANCE_SLUG}" != "${ORIGINAL_SLUG}" ]; then
    sed -i.bak "s/${ORIGINAL_SLUG}/${INSTANCE_SLUG}/g" docker-compose.override.yml
    rm docker-compose.override.yml.bak
  fi
fi

# Restore database
echo -e "${YELLOW}Restoring database...${NC}"
docker-compose up -d postgres
sleep 10
docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS allspark_${INSTANCE_SLUG}_development;"
docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE allspark_${INSTANCE_SLUG}_development;"
docker-compose exec -T postgres psql -U postgres "allspark_${INSTANCE_SLUG}_development" < "${BACKUP_DIR}/database.sql"

# Restore volumes
echo -e "${YELLOW}Restoring Docker volumes...${NC}"
docker run --rm \
  -v "${INSTANCE_SLUG}_postgres_data:/target" \
  -v "${BACKUP_DIR}:/backup:ro" \
  alpine sh -c "rm -rf /target/* && tar -xzf /backup/postgres_data.tar.gz -C /target"

docker run --rm \
  -v "${INSTANCE_SLUG}_redis_data:/target" \
  -v "${BACKUP_DIR}:/backup:ro" \
  alpine sh -c "rm -rf /target/* && tar -xzf /backup/redis_data.tar.gz -C /target"

# Restore uploaded files
if [ -f "${BACKUP_DIR}/storage.tar.gz" ]; then
  echo -e "${YELLOW}Restoring uploaded files...${NC}"
  tar -xzf "${BACKUP_DIR}/storage.tar.gz" -C .
fi

# Start the restored instance
echo -e "${YELLOW}Starting restored instance...${NC}"
docker-compose up -d

# Clean up
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${TEMP_DIR}"

# Run health check
echo -e "${YELLOW}Running health check...${NC}"
sleep 15
"${ALLSPARK_ROOT}/bin/health-check.sh" "${INSTANCE_SLUG}"

echo -e "${GREEN}Instance restored successfully!${NC}"
echo -e "Access your instance at: ${BLUE}http://${INSTANCE_SLUG}.localhost${NC}"