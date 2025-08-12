#!/bin/bash

echo "🌐 Checking Workshop Website Status..."
echo "======================================"

# Website URLs to check
GITHUB_PAGES_URL="https://binh2423.github.io/ECS_Advanced_Networking/"
LOCAL_URL="http://localhost:1313"

echo "📍 GitHub Pages URL: $GITHUB_PAGES_URL"
echo "📍 Local Dev URL: $LOCAL_URL"
echo ""

# Function to check URL status
check_url() {
    local url=$1
    local name=$2
    
    echo "🔍 Checking $name..."
    
    if curl -s --head "$url" | head -n 1 | grep -q "200 OK"; then
        echo "✅ $name is ONLINE"
        
        # Check if it contains workshop content
        if curl -s "$url" | grep -q "Workshop ECS Advanced Networking"; then
            echo "✅ $name contains workshop content"
        else
            echo "⚠️  $name is online but may not have correct content"
        fi
    else
        echo "❌ $name is OFFLINE or not accessible"
    fi
    echo ""
}

# Check GitHub Pages
check_url "$GITHUB_PAGES_URL" "GitHub Pages"

# Check if local server is running
if curl -s --head "$LOCAL_URL" >/dev/null 2>&1; then
    check_url "$LOCAL_URL" "Local Development Server"
else
    echo "ℹ️  Local development server is not running"
    echo "   To start: ./serve-local.sh"
    echo ""
fi

# Check GitHub Actions status
echo "🔄 GitHub Actions Status:"
echo "========================="
echo "Repository: https://github.com/Binh2423/ECS_Advanced_Networking"
echo "Actions: https://github.com/Binh2423/ECS_Advanced_Networking/actions"
echo ""

# Show recent commits
echo "📝 Recent Commits:"
echo "=================="
git log --oneline -5
echo ""

# Show file structure
echo "📁 Workshop Structure:"
echo "====================="
echo "Content Pages:"
find content -name "_index.md" | sort
echo ""
echo "Images:"
ls -1 static/images/ | wc -l
echo "images available"
echo ""

# Show build info
echo "🏗️  Build Information:"
echo "====================="
echo "Hugo Version: $(hugo version 2>/dev/null || echo 'Hugo not found')"
echo "Last Build: $(date -r public/index.html 2>/dev/null || echo 'Not built yet')"
echo "Site Pages: $(find public -name "index.html" | wc -l) pages"
echo ""

echo "🎉 Website Check Complete!"
echo ""
echo "🚀 To access the workshop:"
echo "   Online: $GITHUB_PAGES_URL"
echo "   Local:  Start with ./serve-local.sh then visit $LOCAL_URL"
