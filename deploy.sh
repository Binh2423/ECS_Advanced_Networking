#!/bin/bash

echo "🚀 Deploying ECS Advanced Networking Workshop to GitHub Pages..."
echo "================================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "hugo.toml" ]; then
    print_error "hugo.toml not found. Please run this script from the workshop root directory."
    exit 1
fi

# Check if Hugo is installed
if ! command -v hugo &> /dev/null; then
    print_error "Hugo is not installed. Please install Hugo first."
    exit 1
fi

print_status "Checking Hugo version..."
hugo version

# Clean previous build
print_status "Cleaning previous build..."
rm -rf public/

# Build the site
print_status "Building Hugo site for production..."
if hugo --gc --minify; then
    print_success "Site built successfully!"
else
    print_error "Failed to build site"
    exit 1
fi

# Check git status
print_status "Checking git status..."
if [ -n "$(git status --porcelain)" ]; then
    print_warning "You have uncommitted changes. Committing them now..."
    
    # Add all changes
    git add .
    
    # Commit with timestamp
    commit_message="🚀 Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$commit_message"
    
    print_success "Changes committed: $commit_message"
else
    print_status "No uncommitted changes found."
fi

# Push to GitHub
print_status "Pushing to GitHub..."
if git push origin main; then
    print_success "Successfully pushed to GitHub!"
else
    print_error "Failed to push to GitHub"
    exit 1
fi

# Get the GitHub Pages URL
REPO_URL=$(git config --get remote.origin.url)
if [[ $REPO_URL == *"github.com"* ]]; then
    # Extract username and repo name
    REPO_PATH=$(echo $REPO_URL | sed 's/.*github\.com[:/]\([^/]*\/[^/]*\)\.git.*/\1/')
    USERNAME=$(echo $REPO_PATH | cut -d'/' -f1)
    REPO_NAME=$(echo $REPO_PATH | cut -d'/' -f2)
    
    PAGES_URL="https://${USERNAME}.github.io/${REPO_NAME}/"
    
    print_success "Deployment completed!"
    echo ""
    echo "📖 Your workshop will be available at:"
    echo "   $PAGES_URL"
    echo ""
    echo "⏳ Note: It may take a few minutes for GitHub Pages to update."
    echo "🔧 Make sure GitHub Pages is enabled in your repository settings."
    echo ""
    echo "📋 To check deployment status:"
    echo "   https://github.com/${REPO_PATH}/actions"
else
    print_success "Deployment completed!"
    print_warning "Could not determine GitHub Pages URL from remote origin."
fi

echo ""
print_success "🎉 Deployment script completed successfully!"
