#!/bin/bash

# 🖼️ Fix Image Paths Script
# This script fixes image paths in all content files to work with GitHub Pages

set -e

echo "🖼️ Fixing Image Paths for GitHub Pages"
echo "======================================"

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

# Check if we're in the right directory
if [ ! -f "hugo.toml" ]; then
    echo -e "${RED}❌ Not in Hugo project directory. Please run from project root.${NC}"
    exit 1
fi

print_info "Scanning content files for image references..."

# Find all markdown files with image references
CONTENT_FILES=$(find content/ -name "*.md" -type f)
FIXED_COUNT=0
TOTAL_IMAGES=0

for file in $CONTENT_FILES; do
    print_info "Processing: $file"
    
    # Count current images in this file
    CURRENT_IMAGES=$(grep -c "!\[.*\](" "$file" 2>/dev/null || echo "0")
    TOTAL_IMAGES=$((TOTAL_IMAGES + CURRENT_IMAGES))
    
    if [ "$CURRENT_IMAGES" -gt 0 ]; then
        print_info "  Found $CURRENT_IMAGES image(s)"
        
        # Create backup
        cp "$file" "$file.backup"
        
        # Fix image paths - add leading slash if not present
        # Pattern: ![text](images/path) -> ![text](/images/path)
        sed -i 's|!\[\([^]]*\)\](images/|![\1](/images/|g' "$file"
        
        # Also fix any remaining relative paths
        # Pattern: ![text](../static/images/path) -> ![text](/images/path)
        sed -i 's|!\[\([^]]*\)\](../static/images/|![\1](/images/|g' "$file"
        sed -i 's|!\[\([^]]*\)\](./images/|![\1](/images/|g' "$file"
        
        # Check if file was actually changed
        if ! cmp -s "$file" "$file.backup"; then
            print_status "  Fixed image paths in $file"
            FIXED_COUNT=$((FIXED_COUNT + 1))
        else
            print_info "  No changes needed in $file"
        fi
        
        # Remove backup
        rm "$file.backup"
    fi
done

echo ""
print_status "Image path fixing complete!"
print_info "Total files processed: $(echo "$CONTENT_FILES" | wc -l)"
print_info "Files with images: $FIXED_COUNT"
print_info "Total image references: $TOTAL_IMAGES"

# Test Hugo build after changes
echo ""
print_info "Testing Hugo build after changes..."
if hugo --gc --minify > /dev/null 2>&1; then
    print_status "Hugo build successful after image path fixes"
else
    echo -e "${RED}❌ Hugo build failed after changes${NC}"
    print_info "Running verbose build to show errors:"
    hugo --gc --minify --verbose
    exit 1
fi

# Show some examples of fixed paths
echo ""
print_info "Examples of fixed image paths:"
grep -r "!\[.*\](/images/" content/ | head -5 | while read line; do
    echo "  $line"
done

echo ""
print_info "🎯 Next steps:"
echo "1. Review the changes: git diff"
echo "2. Test locally: hugo server"
echo "3. Commit and push: git add . && git commit -m 'Fix image paths' && git push"

echo ""
print_status "All image paths have been fixed for GitHub Pages!"
