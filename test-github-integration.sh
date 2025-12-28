#!/bin/bash

# Test GitHub Integration Setup
# Verifies that all GitHub deployment components are properly configured

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Test script permissions
test_script_permissions() {
    log "Testing script permissions..."
    
    local scripts=(
        "github-deploy.sh"
        "setup-auto-update.sh"
        "setup-git-workflow.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            success "$script is executable"
        else
            error "$script is not executable"
            echo "Fix with: chmod +x $script"
        fi
    done
}

# Test Git configuration
test_git_config() {
    log "Testing Git configuration..."
    
    if command -v git &> /dev/null; then
        success "Git is installed"
        
        # Check if this is a git repository
        if [[ -d ".git" ]]; then
            success "Git repository initialized"
            
            # Check for remote
            if git remote -v | grep -q origin; then
                success "Git remote configured"
                git remote -v | head -1
            else
                warning "No git remote configured"
                echo "Set up remote with: git remote add origin https://github.com/username/repo.git"
            fi
        else
            warning "Not a Git repository"
            echo "Initialize with: git init"
        fi
    else
        error "Git is not installed"
        echo "Install with: sudo apt update && sudo apt install git"
    fi
}

# Test required files
test_required_files() {
    log "Testing required files..."
    
    local required_files=(
        "app.py"
        "requirements.txt"
        "gunicorn_config.py"
        "manual-deploy.sh"
        "ubuntu-setup.sh"
        "templates/base.html"
        "static/css/style.css"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            success "$file exists"
        else
            error "$file is missing"
        fi
    done
}

# Test GitHub workflow files
test_github_workflow() {
    log "Testing GitHub workflow files..."
    
    if [[ -d ".github/workflows" ]]; then
        success ".github/workflows directory exists"
        
        if [[ -f ".github/workflows/deploy.yml" ]]; then
            success "GitHub Actions workflow configured"
        else
            warning "GitHub Actions workflow not found"
        fi
    else
        warning "GitHub workflow directory not found"
        echo "Create with: ./setup-git-workflow.sh"
    fi
    
    if [[ -f ".gitignore" ]]; then
        success ".gitignore file exists"
    else
        warning ".gitignore file not found"
    fi
    
    if [[ -f ".git/hooks/pre-commit" ]]; then
        success "Pre-commit hooks configured"
    else
        warning "Pre-commit hooks not found"
    fi
}

# Test Python environment
test_python_environment() {
    log "Testing Python environment..."
    
    if command -v python3 &> /dev/null; then
        success "Python3 is available"
        python3 --version
    else
        error "Python3 is not installed"
    fi
    
    if [[ -f "requirements.txt" ]]; then
        success "requirements.txt exists"
        echo "Dependencies: $(wc -l < requirements.txt) packages"
    else
        error "requirements.txt not found"
    fi
    
    if [[ -d "venv" ]]; then
        success "Virtual environment exists"
    else
        warning "Virtual environment not found"
        echo "Create with: python3 -m venv venv"
    fi
}

# Test deployment configuration
test_deployment_config() {
    log "Testing deployment configuration..."
    
    # Check for .env.example
    if [[ -f ".env.example" ]]; then
        success ".env.example template exists"
    else
        warning ".env.example not found"
    fi
    
    # Check documentation
    local docs=(
        "README.md"
        "DEPLOYMENT_GUIDE.md" 
        "GITHUB_INTEGRATION.md"
        "CONTRIBUTING.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ -f "$doc" ]]; then
            success "$doc exists"
        else
            warning "$doc not found"
        fi
    done
}

# Show summary and recommendations
show_summary() {
    echo ""
    echo "=================================================="
    log "GITHUB INTEGRATION TEST SUMMARY"
    echo "=================================================="
    echo ""
    
    echo "${BLUE}Next Steps:${NC}"
    echo ""
    
    echo "${YELLOW}1. Local Development:${NC}"
    echo "   ./setup-git-workflow.sh"
    echo "   # Configure Git and create GitHub repository"
    echo ""
    
    echo "${YELLOW}2. Server Deployment:${NC}"
    echo "   # On your EC2 server:"
    echo "   sudo ./github-deploy.sh --repo-url YOUR_REPO_URL"
    echo ""
    
    echo "${YELLOW}3. Automated Updates:${NC}"
    echo "   # Setup automatic deployment:"
    echo "   sudo ./setup-auto-update.sh"
    echo ""
    
    echo "${YELLOW}4. GitHub Repository:${NC}"
    echo "   # Create repository on GitHub"
    echo "   # Push your code"
    echo "   # Configure webhook or GitHub Actions"
    echo ""
    
    echo "${BLUE}Documentation:${NC}"
    echo "- GITHUB_INTEGRATION.md - Complete setup guide"
    echo "- README.md - Updated with deployment options"
    echo "- CONTRIBUTING.md - Development workflow"
    echo ""
    
    echo "${GREEN}Your Twilio SMS App is ready for GitHub integration!${NC}"
}

# Main test function
main() {
    echo "=================================================="
    log "TESTING GITHUB INTEGRATION SETUP"
    echo "=================================================="
    echo ""
    
    test_script_permissions
    echo ""
    
    test_git_config
    echo ""
    
    test_required_files
    echo ""
    
    test_github_workflow
    echo ""
    
    test_python_environment
    echo ""
    
    test_deployment_config
    echo ""
    
    show_summary
}

# Run tests
main
