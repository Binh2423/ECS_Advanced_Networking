#!/bin/bash

echo "🚀 Starting ECS Advanced Networking Workshop..."
echo "📖 Workshop will be available at: http://localhost:1313"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start Hugo development server
hugo server --bind 0.0.0.0 --port 1313 --disableFastRender
