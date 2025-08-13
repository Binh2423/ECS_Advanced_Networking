#!/bin/bash

# 🔧 GitHub Pages Auto-Fix Script
# This script automatically detects and fixes common GitHub Pages issues

set -e

echo "🚀 GitHub Pages Auto-Fix Script"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "hugo.toml" ]; then
    print_error "Not in Hugo project directory. Please run from project root."
    exit 1
fi

print_info "Starting GitHub Pages diagnostics..."

# 1. Check for .nojekyll file
echo ""
echo "1. Checking .nojekyll file..."
if [ -f ".nojekyll" ]; then
    print_status ".nojekyll file exists"
else
    print_warning "Creating .nojekyll file"
    echo "" > .nojekyll
    print_status ".nojekyll file created"
fi

# 2. Check for problematic filenames
echo ""
echo "2. Checking for problematic filenames..."
PROBLEMATIC_FILES=$(find . -name "*[[:space:]]*" -o -name "*.png.png" -o -name "*.jpg.jpg" -o -name "*.jpeg.jpeg" 2>/dev/null || true)
if [ -z "$PROBLEMATIC_FILES" ]; then
    print_status "No problematic filenames found"
else
    print_error "Found problematic filenames:"
    echo "$PROBLEMATIC_FILES"
    print_info "Please rename these files manually"
fi

# 3. Check for large files
echo ""
echo "3. Checking for large files (>5MB)..."
LARGE_FILES=$(find . -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" | xargs ls -l 2>/dev/null | awk '$5 > 5242880 {print $9 " (" $5/1024/1024 "MB)"}' || true)
if [ -z "$LARGE_FILES" ]; then
    print_status "No large image files found"
else
    print_warning "Found large image files:"
    echo "$LARGE_FILES"
    print_info "Consider optimizing these images"
fi

# 4. Check Hugo build
echo ""
echo "4. Testing Hugo build..."
if hugo --gc --minify > /dev/null 2>&1; then
    print_status "Hugo build successful"
else
    print_error "Hugo build failed"
    print_info "Running verbose build to show errors:"
    hugo --gc --minify --verbose
    exit 1
fi

# 5. Check date formats in content files
echo ""
echo "5. Checking date formats in content files..."
INVALID_DATES=$(grep -r "date.*\`r Sys.Date()\`" content/ 2>/dev/null || true)
if [ -z "$INVALID_DATES" ]; then
    print_status "All date formats are correct"
else
    print_error "Found invalid date formats:"
    echo "$INVALID_DATES"
    print_info "These need to be fixed manually"
fi

# 6. Check GitHub workflow file
echo ""
echo "6. Checking GitHub Actions workflow..."
if [ -f ".github/workflows/hugo.yml" ]; then
    print_status "GitHub Actions workflow exists"
    
    # Check if workflow uses correct Hugo version
    if grep -q "HUGO_VERSION: 0.128.0" .github/workflows/hugo.yml; then
        print_status "Hugo version is correct (0.128.0)"
    else
        print_warning "Hugo version might need updating"
    fi
else
    print_error "GitHub Actions workflow missing"
    print_info "Please ensure .github/workflows/hugo.yml exists"
fi

# 7. Check repository size
echo ""
echo "7. Checking repository size..."
REPO_SIZE=$(du -sh . | cut -f1)
print_info "Repository size: $REPO_SIZE"

if [[ "$REPO_SIZE" =~ ^[0-9]+M$ ]] && [ "${REPO_SIZE%M}" -lt 100 ]; then
    print_status "Repository size is acceptable"
elif [[ "$REPO_SIZE" =~ ^[0-9]+K$ ]]; then
    print_status "Repository size is acceptable"
else
    print_warning "Repository size might be too large for GitHub Pages"
fi

# 8. Check git status
echo ""
echo "8. Checking git status..."
if git diff --quiet && git diff --cached --quiet; then
    print_status "No uncommitted changes"
else
    print_warning "There are uncommitted changes"
    print_info "Current git status:"
    git status --short
fi

# 9. Generate summary report
echo ""
echo "📊 SUMMARY REPORT"
echo "=================="

# Count images
IMAGE_COUNT=$(find static/images -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" 2>/dev/null | wc -l)
print_info "Total images: $IMAGE_COUNT"

# Check if public directory exists and has content
if [ -d "public" ] && [ "$(ls -A public)" ]; then
    PUBLIC_FILES=$(find public -type f | wc -l)
    print_info "Generated files in public/: $PUBLIC_FILES"
else
    print_warning "Public directory is empty or missing"
fi

echo ""
echo "🎯 NEXT STEPS:"
echo "1. Ensure GitHub Pages Settings → Source = 'GitHub Actions'"
echo "2. Push any changes to trigger deployment"
echo "3. Monitor GitHub Actions workflow"
echo "4. Test website at: https://binh2423.github.io/ECS_Advanced_Networking/"

echo ""
echo "🔗 USEFUL LINKS:"
echo "• Repository: https://github.com/Binh2423/ECS_Advanced_Networking"
echo "• Actions: https://github.com/Binh2423/ECS_Advanced_Networking/actions"
echo "• Settings: https://github.com/Binh2423/ECS_Advanced_Networking/settings/pages"

# 10. Offer to commit and push changes
echo ""
if ! git diff --quiet || ! git diff --cached --quiet; then
    read -p "🤔 Do you want to commit and push changes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Committing changes..."
        git add .
        git commit -m "🔧 Auto-fix GitHub Pages issues"
        
        print_info "Pushing to GitHub..."
        git push origin main
        
        print_status "Changes pushed successfully!"
        print_info "Check GitHub Actions for deployment status"
    fi
fi

echo ""
print_status "GitHub Pages diagnostic complete!"
