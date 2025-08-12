#!/bin/bash

echo "🚀 Monitoring GitHub Actions Deployment..."
echo "=========================================="

REPO_URL="https://github.com/Binh2423/ECS_Advanced_Networking"
ACTIONS_URL="$REPO_URL/actions"
PAGES_URL="https://binh2423.github.io/ECS_Advanced_Networking/"

echo "📍 Repository: $REPO_URL"
echo "📍 Actions: $ACTIONS_URL"
echo "📍 Live Site: $PAGES_URL"
echo ""

echo "🔄 Recent Commits:"
git log --oneline -5
echo ""

echo "📊 Build Status:"
echo "================"
echo "Hugo Version: $(hugo version)"
echo "Last Local Build: $(date -r public/index.html 2>/dev/null || echo 'Not built')"
echo "Site Pages: $(find public -name "index.html" | wc -l) pages generated"
echo "Static Files: $(find public -type f | wc -l) total files"
echo ""

echo "🌐 Deployment Check:"
echo "===================="

# Function to check if site is live
check_deployment() {
    echo "🔍 Checking if site is live..."
    
    if curl -s --head "$PAGES_URL" | head -n 1 | grep -q "200 OK"; then
        echo "✅ Site is LIVE and accessible"
        
        # Check content
        if curl -s "$PAGES_URL" | grep -q "Workshop ECS Advanced Networking"; then
            echo "✅ Content is correct and up to date"
        else
            echo "⚠️  Site is live but content may be outdated"
        fi
    else
        echo "⏳ Site is not yet live (deployment may be in progress)"
        echo "   This is normal for new deployments - wait 5-10 minutes"
    fi
}

check_deployment
echo ""

echo "📋 Next Steps:"
echo "=============="
echo "1. Visit GitHub Actions: $ACTIONS_URL"
echo "2. Check deployment status (should show green checkmark)"
echo "3. Wait 5-10 minutes for GitHub Pages to update"
echo "4. Visit live site: $PAGES_URL"
echo ""

echo "🔧 If deployment fails:"
echo "======================="
echo "- Check GitHub Actions logs for errors"
echo "- Verify repository settings > Pages is enabled"
echo "- Ensure workflow has proper permissions"
echo "- Re-run failed workflow if needed"
echo ""

echo "✅ Monitoring complete!"
