#!/bin/bash
# Switch between Simple and Dual-Container modes

# Navigate to project root
cd "$(dirname "$0")/.."

# Function to check current mode
check_current_mode() {
    if docker-compose ps 2>/dev/null | grep -q "allspark-web-1.*Up"; then
        echo "simple"
    elif docker-compose -f docker-compose.dual.yml ps 2>/dev/null | grep -q "allspark-builder-1.*Up"; then
        echo "dual"
    else
        echo "none"
    fi
}

# Function to display usage
show_usage() {
    current_mode=$(check_current_mode)
    
    echo "🔄 Allspark Mode Switcher"
    echo ""
    echo "Current mode: $current_mode"
    echo ""
    echo "Usage: ./bin/switch-mode.sh [simple|dual]"
    echo ""
    echo "Modes:"
    echo "  simple - Single Allspark instance (default)"
    echo "           Best for: Solo development, getting started"
    echo "           Port: 3000"
    echo ""
    echo "  dual   - Builder + Target architecture"
    echo "           Best for: Team development, complex projects"
    echo "           Ports: Builder (3001), Target (3000)"
    echo ""
    echo "Examples:"
    echo "  ./bin/switch-mode.sh simple    # Switch to simple mode"
    echo "  ./bin/switch-mode.sh dual      # Switch to dual mode"
}

# Main logic
case "$1" in
    simple)
        echo "🔄 Switching to Simple Mode..."
        ./bin/start-simple.sh
        ;;
    dual)
        echo "🔄 Switching to Dual-Container Mode..."
        ./bin/start-dual.sh
        ;;
    status)
        current_mode=$(check_current_mode)
        if [ "$current_mode" = "simple" ]; then
            echo "📦 Currently running in Simple Mode"
            echo "🌐 Access at: http://localhost:3000"
            docker-compose ps
        elif [ "$current_mode" = "dual" ]; then
            echo "📦 Currently running in Dual-Container Mode"
            echo "🏗️  Builder: http://localhost:3001"
            echo "🎯 Target: http://localhost:3000"
            docker-compose -f docker-compose.dual.yml ps
        else
            echo "❌ No Allspark containers are currently running"
            echo "💡 Start with: ./bin/switch-mode.sh [simple|dual]"
        fi
        ;;
    *)
        show_usage
        ;;
esac