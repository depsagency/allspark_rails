#!/bin/bash

# Script to check health of an AllSpark instance
# Usage: ./bin/health-check.sh <instance_slug>

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

# Check if instance directory exists
if [ ! -d "${INSTANCE_DIR}" ]; then
  echo -e "${RED}Error: Instance '${INSTANCE_SLUG}' not found at ${INSTANCE_DIR}${NC}"
  exit 1
fi

echo -e "${BLUE}Health Check for instance: ${INSTANCE_SLUG}${NC}"
echo "================================================"

# Change to instance directory
cd "${INSTANCE_DIR}/allspark"

# Check container status
echo -e "\n${YELLOW}Container Status:${NC}"
docker-compose ps

# Check web service health
echo -e "\n${YELLOW}Web Service Health:${NC}"
if docker-compose exec -T web curl -f -s http://localhost:3000/up > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Web service is healthy${NC}"
else
  echo -e "${RED}✗ Web service is not responding${NC}"
fi

# Check database connectivity
echo -e "\n${YELLOW}Database Health:${NC}"
if docker-compose exec -T web rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Database connection is healthy${NC}"
else
  echo -e "${RED}✗ Database connection failed${NC}"
fi

# Check Redis connectivity
echo -e "\n${YELLOW}Redis Health:${NC}"
if docker-compose exec -T web rails runner "Redis.new.ping" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Redis connection is healthy${NC}"
else
  echo -e "${RED}✗ Redis connection failed${NC}"
fi

# Check Sidekiq status
echo -e "\n${YELLOW}Sidekiq Status:${NC}"
if docker-compose exec -T sidekiq ps aux | grep -q sidekiq; then
  echo -e "${GREEN}✓ Sidekiq is running${NC}"
else
  echo -e "${RED}✗ Sidekiq is not running${NC}"
fi

# Check disk usage
echo -e "\n${YELLOW}Disk Usage:${NC}"
df -h "${INSTANCE_DIR}"

# Check resource usage
echo -e "\n${YELLOW}Container Resource Usage:${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
  "${INSTANCE_SLUG}_web" \
  "${INSTANCE_SLUG}_postgres" \
  "${INSTANCE_SLUG}_redis" \
  "${INSTANCE_SLUG}_sidekiq" 2>/dev/null || true

echo -e "\n${BLUE}Health check completed for instance: ${INSTANCE_SLUG}${NC}"