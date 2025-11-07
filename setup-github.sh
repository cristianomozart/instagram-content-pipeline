#!/bin/bash
# setup-github.sh - Helper script to prepare and push to GitHub

set -e  # Exit on error

echo "🚀 Instagram Content Pipeline - GitHub Setup Helper"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Check if in correct directory
echo "Step 1: Checking directory structure..."
if [ ! -f "README.md" ] || [ ! -f "QUICKSTART.md" ]; then
    print_error "Not in the correct directory. Please run this from instagram-content-pipeline/"
    exit 1
fi
print_success "Directory structure looks good"
echo ""

# Step 2: Check for workflow file
echo "Step 2: Checking for workflow export..."
if [ ! -f "workflow/instagram-pinecone.json" ]; then
    print_warning "Workflow JSON not found"
    echo "   Please export your workflow from n8n and place it in:"
    echo "   workflow/instagram-pinecone.json"
    echo ""
    echo "   See workflow/README.md for detailed instructions"
    read -p "   Press Enter when ready to continue, or Ctrl+C to exit..."
else
    print_success "Workflow JSON found"
fi
echo ""

# Step 3: Security check for sensitive data
echo "Step 3: Scanning for potential secrets..."
echo "   Checking workflow JSON for sensitive data..."

if [ -f "workflow/instagram-pinecone.json" ]; then
    # Check for common sensitive patterns
    FOUND_SECRETS=false
    
    if grep -q '"apiKey":\s*"[^{]' workflow/instagram-pinecone.json 2>/dev/null; then
        print_error "Found potential API key in workflow JSON"
        FOUND_SECRETS=true
    fi
    
    if grep -q '"token":\s*"[^{]' workflow/instagram-pinecone.json 2>/dev/null; then
        print_error "Found potential token in workflow JSON"
        FOUND_SECRETS=true
    fi
    
    if grep -q '"bearer":\s*"[^{]' workflow/instagram-pinecone.json 2>/dev/null; then
        print_error "Found potential bearer token in workflow JSON"
        FOUND_SECRETS=true
    fi
    
    if [ "$FOUND_SECRETS" = true ]; then
        print_error "Sensitive data detected! Please clean the workflow JSON first."
        echo ""
        echo "   See workflow/README.md for cleanup instructions"
        echo ""
        exit 1
    else
        print_success "No obvious secrets detected"
    fi
fi
echo ""

# Step 4: Check for screenshots
echo "Step 4: Checking for screenshots..."
SCREENSHOT_COUNT=$(ls assets/*.png 2>/dev/null | wc -l)
if [ "$SCREENSHOT_COUNT" -lt 3 ]; then
    print_warning "Recommended screenshots not found (found: $SCREENSHOT_COUNT, need: 3)"
    echo "   Suggested screenshots:"
    echo "   - workflow-overview.png"
    echo "   - validation-nodes.png"
    echo "   - error-routing.png"
    echo ""
    echo "   See assets/README.md for instructions"
    read -p "   Continue without screenshots? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "Found $SCREENSHOT_COUNT screenshot(s)"
fi
echo ""

# Step 5: Update README with your name
echo "Step 5: Personalizing documentation..."
read -p "   Your name (for LICENSE): " USER_NAME
if [ ! -z "$USER_NAME" ]; then
    sed -i.bak "s/\[Your Name\]/$USER_NAME/g" LICENSE
    sed -i.bak "s/\[Your Name\]/$USER_NAME/g" README.md
    rm -f LICENSE.bak README.md.bak
    print_success "Updated name in LICENSE and README"
fi
echo ""

# Step 6: Git initialization
echo "Step 6: Git repository setup..."
if [ ! -d ".git" ]; then
    echo "   Initializing git repository..."
    git init
    print_success "Git initialized"
else
    print_warning "Git already initialized"
fi
echo ""

# Step 7: GitHub repository creation prompt
echo "Step 7: GitHub repository connection..."
echo "   Before continuing, create a repository on GitHub:"
echo ""
echo "   1. Go to https://github.com/new"
echo "   2. Repository name: instagram-content-pipeline"
echo "   3. Description: Automated Instagram content extraction and vector storage"
echo "   4. Public (for portfolio visibility)"
echo "   5. DON'T initialize with README (you already have one)"
echo "   6. Click 'Create repository'"
echo ""
read -p "   Have you created the GitHub repository? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Please create the GitHub repository first, then run this script again"
    exit 0
fi

read -p "   Your GitHub username: " GITHUB_USER
if [ -z "$GITHUB_USER" ]; then
    print_error "GitHub username required"
    exit 1
fi

# Step 8: Add files to git
echo ""
echo "Step 8: Staging files..."
git add .
print_success "Files staged"
echo ""

# Step 9: Commit
echo "Step 9: Creating initial commit..."
git commit -m "Initial commit: Instagram to Pinecone workflow documentation

- Comprehensive README with project overview
- QUICKSTART guide for setup and deployment
- Technical architecture documentation
- Complete bug fix changelog
- Security-conscious .gitignore
- MIT License" || {
    print_warning "Nothing to commit (files may already be committed)"
}
print_success "Commit created"
echo ""

# Step 10: Connect to GitHub
echo "Step 10: Connecting to GitHub..."
REMOTE_URL="https://github.com/$GITHUB_USER/instagram-content-pipeline.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL"
print_success "Connected to $REMOTE_URL"
echo ""

# Step 11: Push to GitHub
echo "Step 11: Pushing to GitHub..."
git branch -M main
echo "   Pushing to main branch..."
echo "   You may be prompted for GitHub credentials"
echo ""

if git push -u origin main; then
    print_success "Successfully pushed to GitHub!"
    echo ""
    echo "🎉 Setup complete!"
    echo ""
    echo "Your project is now live at:"
    echo "   https://github.com/$GITHUB_USER/instagram-content-pipeline"
    echo ""
    echo "Next steps:"
    echo "   1. Visit the URL above to verify everything looks good"
    echo "   2. Check that README renders correctly"
    echo "   3. Verify no sensitive data is visible"
    echo "   4. Add to your resume/portfolio"
    echo "   5. Share on LinkedIn!"
    echo ""
else
    print_error "Push failed"
    echo ""
    echo "Common reasons:"
    echo "   - GitHub credentials not configured"
    echo "   - Repository doesn't exist"
    echo "   - Network issues"
    echo ""
    echo "Try:"
    echo "   git push -u origin main"
    echo ""
    echo "If using SSH keys:"
    echo "   git remote set-url origin git@github.com:$GITHUB_USER/instagram-content-pipeline.git"
    echo "   git push -u origin main"
    exit 1
fi

# Optional: Open in browser
echo ""
read -p "Open repository in browser? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open "https://github.com/$GITHUB_USER/instagram-content-pipeline"
    elif command -v open &> /dev/null; then
        open "https://github.com/$GITHUB_USER/instagram-content-pipeline"
    else
        echo "   Visit: https://github.com/$GITHUB_USER/instagram-content-pipeline"
    fi
fi

echo ""
print_success "All done! Good luck with your job search! 🚀"
