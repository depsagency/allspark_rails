#!/bin/bash
# Start Allspark in Simple Mode (single container)

echo "🚀 Starting Allspark in Simple Mode..."
echo "   Single container with all features"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.."

# Stop any running containers
echo "🛑 Stopping any existing containers..."
docker-compose down 2>/dev/null
docker-compose -f docker-compose.dual.yml down 2>/dev/null

# Start simple mode
echo "📦 Building and starting containers..."
docker-compose up -d --build

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 5

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo "✅ Allspark is running in Simple Mode!"
    echo ""
    echo "🌐 Access your application at: http://localhost:3000"
    echo "📧 Default login: admin@example.com / password123"
    echo ""
    echo "💡 To stop: docker-compose down"
    echo "💡 To view logs: docker-compose logs -f"
    echo "💡 To switch to dual mode: ./bin/start-dual.sh"
else
    echo "❌ Failed to start services. Check logs with: docker-compose logs"
    exit 1
fi