#!/bin/bash

# AllSpark Rails Setup Script
# This script sets up your allspark_rails development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[ALLSPARK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is in use
port_in_use() {
    lsof -i :$1 > /dev/null 2>&1
}

# Welcome message
echo ""
echo "🚀 Welcome to AllSpark Rails Setup!"
echo "====================================="
echo ""
echo "This script will help you set up your allspark_rails development environment."
echo "Built for creators who want to build production apps in hours, not months."
echo ""

# Check prerequisites
print_status "Checking prerequisites..."

# Check for Docker
if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker Desktop first:"
    echo "  macOS: https://docs.docker.com/desktop/install/mac-install/"
    echo "  Linux: https://docs.docker.com/desktop/install/linux-install/"
    echo "  Windows: https://docs.docker.com/desktop/install/windows-install/"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

print_status "✓ Docker is installed and running"

# Check for Docker Compose
if ! command_exists docker-compose && ! docker compose version > /dev/null 2>&1; then
    print_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

print_status "✓ Docker Compose is available"

# Check ports
if port_in_use 3000; then
    print_warning "Port 3000 is already in use. You may need to stop other services."
fi

if port_in_use 5432; then
    print_warning "Port 5432 is already in use. You may need to stop PostgreSQL."
fi

if port_in_use 6379; then
    print_warning "Port 6379 is already in use. You may need to stop Redis."
fi

# Environment setup
print_status "Setting up environment configuration..."

if [ ! -f .env ]; then
    print_info "Creating .env file from template..."
    cp .env.example .env
    print_status "✓ Created .env file"
    
    # Generate SECRET_KEY_BASE if Ruby is available
    if command_exists ruby; then
        print_info "Generating SECRET_KEY_BASE..."
        SECRET_KEY=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
        sed -i.bak "s/SECRET_KEY_BASE=use_rails_secret_to_generate/SECRET_KEY_BASE=${SECRET_KEY}/" .env && rm .env.bak
        print_status "✓ Generated SECRET_KEY_BASE"
    fi
else
    print_info ".env file already exists, skipping..."
fi

# Docker setup
print_status "Setting up Docker containers..."

print_info "Building Docker images (this may take a few minutes)..."
if docker-compose build; then
    print_status "✓ Docker images built successfully"
else
    print_error "Failed to build Docker images"
    exit 1
fi

print_info "Starting services..."
if docker-compose up -d; then
    print_status "✓ Services started successfully"
else
    print_error "Failed to start services"
    exit 1
fi

# Wait for services to be ready
print_info "Waiting for services to be ready..."
sleep 10

# Database setup
print_status "Setting up database..."

print_info "Creating and seeding database..."
if docker-compose exec -T web rails db:create db:migrate db:seed; then
    print_status "✓ Database setup completed"
else
    print_error "Failed to setup database"
    exit 1
fi

# Generate Rails credentials if not exist
print_info "Setting up Rails credentials..."
if ! docker-compose exec -T web test -f config/master.key; then
    docker-compose exec -T web rails credentials:edit --skip >/dev/null 2>&1 || true
    print_status "✓ Rails credentials configured"
fi

# Success message
echo ""
echo "🎉 AllSpark Rails Setup Complete!"
echo "=================================="
echo ""
echo "Your development environment is ready! Here's what you can do now:"
echo ""
echo "📱 Access your application:"
echo "   • Web app: http://localhost:3000"
echo "   • Admin login: admin@example.com / password123"
echo ""
echo "🔧 Development commands:"
echo "   • View logs: docker-compose logs -f web"
echo "   • Rails console: docker-compose exec web rails console"
echo "   • Run tests: docker-compose exec web rails test"
echo "   • Stop services: docker-compose down"
echo ""
echo "📚 Next steps:"
echo "   1. Edit your .env file to configure AI integrations"
echo "   2. Visit http://localhost:3000/app_projects to create your first project"
echo "   3. Check out the documentation at docs/README.md"
echo "   4. Join our Discord: https://discord.gg/allspark"
echo ""
echo "🤖 AI Configuration:"
echo "   • Get OpenRouter API key: https://openrouter.ai"
echo "   • Edit .env file with your keys"
echo "   • Restart services: docker-compose restart web"
echo ""
echo "Happy building! 🚀"
echo ""

# Health check
print_status "Running health check..."
sleep 5

if curl -s http://localhost:3000 >/dev/null 2>&1; then
    print_status "✓ Application is responding at http://localhost:3000"
else
    print_warning "Application might not be ready yet. Give it a few more seconds."
fi