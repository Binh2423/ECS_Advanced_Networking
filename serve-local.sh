#!/bin/bash

echo "🚀 Starting Hugo development server..."
echo "📍 URL: http://localhost:1313"
echo "🔧 Environment: Development"
echo "⏹️  Press Ctrl+C to stop"
echo "-" * 50

# Start Hugo server with live reload
hugo server \
  --bind 0.0.0.0 \
  --port 1313 \
  --baseURL "http://localhost:1313" \
  --buildDrafts \
  --buildFuture \
  --disableFastRender \
  --navigateToChanged \
  --templateMetrics \
  --templateMetricsHints \
  --watch
