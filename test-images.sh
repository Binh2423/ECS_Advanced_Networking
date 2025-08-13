#!/bin/bash

# 🖼️ Test Images on GitHub Pages
# This script tests if images are loading correctly on the deployed website

set -e

echo "🖼️ Testing Images on GitHub Pages"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

BASE_URL="https://binh2423.github.io/ECS_Advanced_Networking"

print_info "Testing website accessibility..."
if curl -s -I "$BASE_URL/" | grep -q "200"; then
    print_status "Website is accessible"
else
    print_error "Website is not accessible"
    exit 1
fi

print_info "Testing sample images..."

# Test some key images
TEST_IMAGES=(
    "/images/3-cluster-setup/vpc-architecture-overview.png"
    "/images/3-cluster-setup/01-vpc/01-aws-console-homepage.png"
    "/images/5-load-balancing/alb-architecture-overview.png"
    "/images/7-monitoring/monitoring-architecture.png"
)

WORKING_IMAGES=0
TOTAL_IMAGES=${#TEST_IMAGES[@]}

for image in "${TEST_IMAGES[@]}"; do
    IMAGE_URL="$BASE_URL$image"
    print_info "Testing: $image"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$IMAGE_URL")
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_status "  Image loads successfully (HTTP $HTTP_CODE)"
        WORKING_IMAGES=$((WORKING_IMAGES + 1))
    else
        print_error "  Image failed to load (HTTP $HTTP_CODE)"
        print_info "  URL: $IMAGE_URL"
    fi
done

echo ""
print_info "📊 Test Results:"
print_info "Working images: $WORKING_IMAGES/$TOTAL_IMAGES"

if [ "$WORKING_IMAGES" -eq "$TOTAL_IMAGES" ]; then
    print_status "All test images are loading correctly!"
else
    print_error "Some images are not loading correctly"
fi

# Test the main page HTML for image references
print_info "Checking main page HTML for image references..."
MAIN_PAGE_HTML=$(curl -s "$BASE_URL/")

# Count img tags in the HTML
IMG_COUNT=$(echo "$MAIN_PAGE_HTML" | grep -o '<img[^>]*>' | wc -l)
print_info "Found $IMG_COUNT <img> tags in main page HTML"

# Check for broken image references
BROKEN_REFS=$(echo "$MAIN_PAGE_HTML" | grep -o 'src="[^"]*"' | grep -v "^src=\"/images/" | grep -v "^src=\"data:" | grep -v "^src=\"https://" || true)
if [ -z "$BROKEN_REFS" ]; then
    print_status "No broken image references found in HTML"
else
    print_error "Found potentially broken image references:"
    echo "$BROKEN_REFS"
fi

echo ""
print_info "🔗 Useful links:"
echo "• Website: $BASE_URL/"
echo "• GitHub Actions: https://github.com/Binh2423/ECS_Advanced_Networking/actions"
echo "• Repository: https://github.com/Binh2423/ECS_Advanced_Networking"

echo ""
if [ "$WORKING_IMAGES" -eq "$TOTAL_IMAGES" ]; then
    print_status "Image testing complete - All images working!"
else
    print_error "Image testing complete - Some issues found"
    print_info "Wait a few minutes for GitHub Pages to update, then test again"
fi
