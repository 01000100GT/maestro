#!/bin/bash

# Maestro startup script with automatic GPU detection

set -e

echo "🚀 Starting Maestro..."

# Source GPU detection
source ./detect_gpu.sh

# Export GPU availability for docker-compose
if [ "$GPU_SUPPORT" = "nvidia" ]; then
    export GPU_AVAILABLE=true
    echo "✅ NVIDIA GPU detected - enabling GPU support"
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.gpu.yml"
else
    export GPU_AVAILABLE=false
    if [ "$GPU_SUPPORT" = "mac" ]; then
        echo "🍎 macOS detected - running in CPU mode"
    else
        echo "💻 No GPU detected - running in CPU mode"
    fi
    COMPOSE_FILES="-f docker-compose.yml"
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Creating from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✅ Created .env file. Please review and update the settings."
    else
        echo "❌ No .env.example file found. Please create a .env file."
        exit 1
    fi
fi

# Source environment variables
export $(grep -v '^#' .env | xargs)

# Check if images exist, build if needed
echo "🐳 Checking Docker images..."
if ! docker images | grep -q "maestro-backend"; then
    echo "📦 Building Docker images for first time setup..."
    docker compose $COMPOSE_FILES build
    echo "📦 Building CLI image..."
    docker compose build cli
else
    # Check if CLI image exists
    if ! docker images | grep -q "maestro-cli"; then
        echo "📦 Building CLI image..."
        docker compose build cli
    fi
fi

# Start services
echo "🐳 Starting Docker services..."
docker compose $COMPOSE_FILES up -d

# Check if services are running
sleep 5
if docker compose ps | grep -q "Up"; then
    echo "✅ Maestro is running!"
    echo ""
    echo "📍 Access MAESTRO at:"
    # Use the new nginx proxy port if available, fallback to old config for backward compatibility
    if [ -n "${MAESTRO_PORT}" ]; then
        if [ "${MAESTRO_PORT}" = "80" ]; then
            echo "   http://localhost"
        else
            echo "   http://localhost:${MAESTRO_PORT}"
        fi
    else
        # Backward compatibility
        echo "   Frontend: http://${FRONTEND_HOST:-localhost}:${FRONTEND_PORT:-3030}"
        echo "   Backend API: http://${BACKEND_HOST:-localhost}:${BACKEND_PORT:-8001}"
    fi
    echo ""
    echo "📊 GPU Status: ${GPU_AVAILABLE}"
    echo ""
    echo "Default login:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    echo "⚠️  IMPORTANT - First Run:"
    echo "   Initial startup takes 5-10 minutes to download AI models"
    echo "   Monitor progress with: docker compose logs -f maestro-backend"
    echo "   Wait for message: Application startup complete"
else
    echo "❌ Failed to start services. Check logs with: docker compose logs"
    exit 1
fi