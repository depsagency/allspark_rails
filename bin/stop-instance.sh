#!/bin/bash

# Script to stop an AllSpark instance
# Usage: ./bin/stop-instance.sh <instance_slug>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo -e "${YELLOW}Stopping instance: ${INSTANCE_SLUG}${NC}"

# Change to instance directory
cd "${INSTANCE_DIR}/allspark"

# Stop containers
echo "Stopping Docker containers..."
docker-compose stop

echo -e "${GREEN}Instance ${INSTANCE_SLUG} stopped successfully!${NC}"