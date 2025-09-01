#!/bin/bash
# Start Allspark in Dual-Container Mode (Builder + Target)

echo "🚀 Starting Allspark in Dual-Container Mode..."
echo "   Builder: Allspark UI for managing projects"
echo "   Target: Development environment with Claude Code"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

# Stop any running containers
echo "🛑 Stopping any existing containers..."
docker-compose down 2>/dev/null
docker-compose -f docker-compose.dual.yml down 2>/dev/null

# Remove existing volumes to ensure clean separation
echo "🗑️  Cleaning up volumes for fresh start..."
docker volume rm allspark_target_app 2>/dev/null || true
docker volume rm allspark_workspace_shared 2>/dev/null || true

# Start dual mode
echo "📦 Building and starting containers..."
docker-compose -f docker-compose.dual.yml up -d --build

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check if services are running
if docker-compose -f docker-compose.dual.yml ps | grep -q "Up"; then
    echo ""
    echo "✅ Allspark is running in Dual-Container Mode!"
    echo ""
    echo "🏗️  Builder UI: http://localhost:3001"
    echo "   - Create and manage app projects"
    echo "   - Generate PRDs, tasks, and Claude prompts"
    echo "   - Access terminal to Target container"
    echo ""
    echo "🎯 Target App: http://localhost:3000"
    echo "   - Your development environment"
    echo "   - Claude Code pre-installed"
    echo "   - Isolated from Builder"
    echo ""
    echo "📧 Default login for both: admin@example.com / password123"
    echo ""
    echo "💡 To stop: docker-compose -f docker-compose.dual.yml down"
    echo "💡 To view logs: docker-compose -f docker-compose.dual.yml logs -f"
    echo "💡 To switch to simple mode: ./bin/start-simple.sh"
    echo "💡 To update Target with Builder changes: ./bin/update-target.sh"
else
    echo "❌ Failed to start services. Check logs with: docker-compose -f docker-compose.dual.yml logs"
    exit 1
fi