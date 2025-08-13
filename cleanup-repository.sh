#!/bin/bash

# 🧹 Repository Cleanup Script
# This script removes unnecessary files and keeps only what's needed for the website

set -e

echo "🧹 Repository Cleanup Script"
echo "============================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "hugo.toml" ]; then
    print_error "Not in Hugo project directory. Please run from project root."
    exit 1
fi

print_info "Starting repository cleanup..."

# 1. Remove unnecessary documentation files
echo ""
print_info "1. Removing unnecessary documentation files..."

FILES_TO_REMOVE=(
    "FINAL_SUMMARY.md"
    "IMAGE_ORGANIZATION_COMPLETE.md"
    "TROUBLESHOOTING_GUIDE.md"
    "hugo.log"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        print_status "Removed: $file"
    fi
done

# 2. Remove unnecessary scripts (keep only essential ones)
echo ""
print_info "2. Removing unnecessary scripts..."

SCRIPTS_TO_REMOVE=(
    "check-website.sh"
    "monitor-deployment.sh"
    "serve-local.sh"
    "serve-workshop.sh"
    "test-images.sh"
    "fix-image-paths.sh"
    "verify-deployment.sh"
)

for script in "${SCRIPTS_TO_REMOVE[@]}"; do
    if [ -f "$script" ]; then
        rm "$script"
        print_status "Removed: $script"
    fi
done

# 3. Clean up public directory (will be regenerated)
echo ""
print_info "3. Cleaning public directory..."
if [ -d "public" ]; then
    rm -rf public/*
    print_status "Cleaned public directory"
fi

# 4. Clean up resources directory
echo ""
print_info "4. Cleaning resources directory..."
if [ -d "resources" ]; then
    rm -rf resources/*
    print_status "Cleaned resources directory"
fi

# 5. Remove Hugo build lock
echo ""
print_info "5. Removing build artifacts..."
if [ -f ".hugo_build.lock" ]; then
    rm ".hugo_build.lock"
    print_status "Removed Hugo build lock"
fi

# 6. Fix the new AWS architecture.png filename (remove space)
echo ""
print_info "6. Fixing AWS architecture.png filename..."
if [ -f "static/images/AWS architecture.png" ]; then
    mv "static/images/AWS architecture.png" "static/images/aws-architecture.png"
    print_status "Renamed 'AWS architecture.png' to 'aws-architecture.png'"
fi

# 7. Remove duplicate images in public directory
echo ""
print_info "7. Removing duplicate images in public directory..."
if [ -d "public/images" ]; then
    rm -rf public/images
    print_status "Removed duplicate images from public directory"
fi

# 8. Clean up theme example files (keep only necessary theme files)
echo ""
print_info "8. Cleaning up theme example files..."
if [ -d "themes/hugo-theme-learn/exampleSite" ]; then
    rm -rf themes/hugo-theme-learn/exampleSite
    print_status "Removed theme example site"
fi

# 9. Remove large unnecessary theme images
echo ""
print_info "9. Removing large theme images..."
THEME_IMAGES_TO_REMOVE=(
    "themes/hugo-theme-learn/images/screenshot.png"
    "themes/hugo-theme-learn/images/tn.png"
)

for img in "${THEME_IMAGES_TO_REMOVE[@]}"; do
    if [ -f "$img" ]; then
        rm "$img"
        print_status "Removed: $img"
    fi
done

# 10. Update .gitignore to prevent unnecessary files
echo ""
print_info "10. Updating .gitignore..."
cat > .gitignore << 'EOF'
# Hugo build artifacts
public/
resources/
.hugo_build.lock

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*.swp
*.swo
*~

# Log files
*.log

# Temporary files
*.tmp
*.temp
EOF

print_status "Updated .gitignore"

# 11. Rebuild Hugo to ensure everything works
echo ""
print_info "11. Testing Hugo build after cleanup..."
if hugo --gc --minify > /dev/null 2>&1; then
    print_status "Hugo build successful after cleanup"
else
    print_error "Hugo build failed after cleanup"
    print_info "Running verbose build to show errors:"
    hugo --gc --minify --verbose
    exit 1
fi

# 12. Show repository size after cleanup
echo ""
print_info "12. Repository size after cleanup:"
REPO_SIZE=$(du -sh . | cut -f1)
print_info "Repository size: $REPO_SIZE"

# 13. Count remaining files
echo ""
print_info "13. File count summary:"
TOTAL_FILES=$(find . -type f | grep -v ".git/" | wc -l)
IMAGE_FILES=$(find static/images -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" 2>/dev/null | wc -l)
CONTENT_FILES=$(find content -name "*.md" 2>/dev/null | wc -l)

print_info "Total files: $TOTAL_FILES"
print_info "Image files: $IMAGE_FILES"
print_info "Content files: $CONTENT_FILES"

echo ""
print_status "🎉 Repository cleanup complete!"

echo ""
print_info "📋 What was cleaned up:"
echo "• ✅ Removed unnecessary documentation files"
echo "• ✅ Removed development/testing scripts"
echo "• ✅ Cleaned build artifacts"
echo "• ✅ Fixed filename with spaces"
echo "• ✅ Removed theme example files"
echo "• ✅ Updated .gitignore"

echo ""
print_info "📁 Essential files kept:"
echo "• ✅ content/ - All workshop content"
echo "• ✅ static/images/ - All workshop images"
echo "• ✅ layouts/ - Custom Hugo layouts"
echo "• ✅ themes/ - Hugo theme (cleaned)"
echo "• ✅ .github/workflows/ - GitHub Actions"
echo "• ✅ hugo.toml - Hugo configuration"
echo "• ✅ README.md - Project documentation"

echo ""
print_info "🎯 Next steps:"
echo "1. Review changes: git status"
echo "2. Test locally: hugo server"
echo "3. Commit changes: git add . && git commit -m 'Clean up repository'"
echo "4. Push to GitHub: git push origin main"

echo ""
print_status "Repository is now clean and optimized for GitHub Pages!"
