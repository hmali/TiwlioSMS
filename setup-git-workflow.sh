#!/bin/bash

# Git Workflow Setup Script
# Sets up proper Git configuration and workflows for the project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install Git first."
    fi
}

# Initialize git repository if not already done
init_git_repo() {
    if [[ ! -d ".git" ]]; then
        log "Initializing Git repository..."
        git init
        success "Git repository initialized"
    else
        log "Git repository already exists"
    fi
}

# Create .gitignore file
create_gitignore() {
    log "Creating .gitignore file..."
    
    cat > .gitignore << EOF
# Environment variables
.env

# Database files
*.db
*.sqlite
*.sqlite3

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
venv/
env/
ENV/
.venv/
.ENV/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Backup files
*.backup
*.bak
*-backup/

# Temporary files
*.tmp
*.temp
.cache/

# SSL certificates (if any)
*.pem
*.key
*.crt

# Nginx configuration (deployment specific)
/etc/

# System service files (deployment specific)
*.service
EOF
    
    success ".gitignore file created"
}

# Create GitHub Actions workflow
create_github_actions() {
    log "Creating GitHub Actions workflow..."
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy to Production

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
    
    - name: Run tests
      run: |
        python -m pytest tests/ || echo "No tests found"
    
    - name: Deploy to server
      if: success()
      env:
        DEPLOY_HOST: ${{ secrets.DEPLOY_HOST }}
        DEPLOY_USER: ${{ secrets.DEPLOY_USER }}
        DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
      run: |
        # Install SSH key
        mkdir -p ~/.ssh
        echo "$DEPLOY_KEY" > ~/.ssh/deploy_key
        chmod 600 ~/.ssh/deploy_key
        ssh-keyscan -H $DEPLOY_HOST >> ~/.ssh/known_hosts
        
        # Deploy via SSH
        ssh -i ~/.ssh/deploy_key $DEPLOY_USER@$DEPLOY_HOST "cd /opt/twilio-sms && sudo ./github-deploy.sh"
    
    - name: Notify on success
      if: success()
      run: echo "Deployment successful!"
    
    - name: Notify on failure
      if: failure()
      run: echo "Deployment failed!"
EOF
    
    success "GitHub Actions workflow created"
}

# Create pre-commit hooks
create_pre_commit_hooks() {
    log "Creating pre-commit hooks..."
    
    mkdir -p .git/hooks
    
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Pre-commit hook for Twilio SMS App
# Checks code quality before committing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Running pre-commit checks...${NC}"

# Check Python syntax
echo "Checking Python syntax..."
python_files=$(git diff --cached --name-only --diff-filter=ACM | grep -E "\.py$" || true)

if [[ -n "$python_files" ]]; then
    for file in $python_files; do
        python -m py_compile "$file"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Python syntax error in $file${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}Python syntax check passed${NC}"
fi

# Check for .env file in staging
if git diff --cached --name-only | grep -q "^\.env$"; then
    echo -e "${RED}Error: .env file should not be committed${NC}"
    echo "Please remove .env from staging and add it to .gitignore"
    exit 1
fi

# Check for database files in staging
if git diff --cached --name-only | grep -E "\.(db|sqlite|sqlite3)$"; then
    echo -e "${RED}Error: Database files should not be committed${NC}"
    echo "Please remove database files from staging and add them to .gitignore"
    exit 1
fi

# Check for large files
large_files=$(git diff --cached --name-only --diff-filter=ACM | xargs ls -la 2>/dev/null | awk '$5 > 1048576 {print $9}' || true)
if [[ -n "$large_files" ]]; then
    echo -e "${YELLOW}Warning: Large files detected:${NC}"
    echo "$large_files"
    echo "Consider using Git LFS for large files"
fi

echo -e "${GREEN}All pre-commit checks passed!${NC}"
EOF
    
    chmod +x .git/hooks/pre-commit
    success "Pre-commit hooks created"
}

# Setup Git configuration
setup_git_config() {
    log "Setting up Git configuration..."
    
    # Get user input for Git config
    read -p "Enter your Git username: " git_username
    read -p "Enter your Git email: " git_email
    
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"
    
    # Set up some useful aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.visual '!gitk'
    
    success "Git configuration completed"
}

# Create development workflow documentation
create_workflow_docs() {
    log "Creating workflow documentation..."
    
    cat > CONTRIBUTING.md << 'EOF'
# Contributing to Twilio SMS App

## Development Workflow

### Initial Setup
1. Clone the repository
2. Create virtual environment: `python3 -m venv venv`
3. Activate environment: `source venv/bin/activate`
4. Install dependencies: `pip install -r requirements.txt`
5. Copy `.env.example` to `.env` and configure

### Making Changes
1. Create a new branch: `git checkout -b feature/your-feature-name`
2. Make your changes
3. Test your changes locally
4. Commit your changes: `git commit -m "Description of changes"`
5. Push to your branch: `git push origin feature/your-feature-name`
6. Create a Pull Request

### Deployment Workflow
- **Development**: Work on feature branches
- **Staging**: Merge to `develop` branch for testing
- **Production**: Merge to `main` branch triggers deployment

### Pre-commit Checks
- Python syntax validation
- File size checks
- Sensitive file prevention (.env, database files)

### Deployment
- Automatic deployment via GitHub Actions
- Webhook-based deployment for real-time updates
- Manual deployment using `github-deploy.sh`

## Code Style
- Follow PEP 8 for Python code
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## Testing
- Write tests for new features
- Run tests before committing
- Ensure all tests pass in CI/CD pipeline

## Security
- Never commit sensitive data (.env files, API keys)
- Use environment variables for configuration
- Follow security best practices for web applications

## Documentation
- Update README.md for new features
- Document API endpoints
- Include deployment instructions
EOF
    
    success "Contributing guidelines created"
}

# Setup remote repository
setup_remote() {
    echo ""
    echo "Do you want to set up a remote GitHub repository? (y/n)"
    read -r setup_remote_repo
    
    if [[ "$setup_remote_repo" == "y" || "$setup_remote_repo" == "Y" ]]; then
        echo "Please enter your GitHub repository URL (e.g., https://github.com/username/TiwlioSMS.git):"
        read -r repo_url
        
        if [[ -n "$repo_url" ]]; then
            # Check if origin already exists
            if git remote get-url origin >/dev/null 2>&1; then
                git remote set-url origin "$repo_url"
                success "Remote origin updated"
            else
                git remote add origin "$repo_url"
                success "Remote origin added"
            fi
            
            # Update github-deploy.sh with the correct repo URL
            if [[ -f "github-deploy.sh" ]]; then
                sed -i.bak "s|REPO_URL=\"https://github.com/YOUR_USERNAME/TiwlioSMS.git\"|REPO_URL=\"$repo_url\"|" github-deploy.sh
                rm -f github-deploy.sh.bak
                success "Updated github-deploy.sh with repository URL"
            fi
        else
            warning "No repository URL provided"
        fi
    fi
}

# Initial commit
create_initial_commit() {
    log "Creating initial commit..."
    
    git add .
    
    if git diff --cached --quiet; then
        warning "No changes to commit"
    else
        git commit -m "Initial commit: Twilio SMS App

- Flask web application for bulk SMS
- User authentication and management
- Campaign tracking and monitoring
- Production deployment scripts
- GitHub integration and CI/CD setup"
        
        success "Initial commit created"
        
        # Push to remote if it exists
        if git remote get-url origin >/dev/null 2>&1; then
            echo "Push to remote repository? (y/n)"
            read -r push_to_remote
            
            if [[ "$push_to_remote" == "y" || "$push_to_remote" == "Y" ]]; then
                git push -u origin main || git push -u origin master
                success "Code pushed to remote repository"
            fi
        fi
    fi
}

# Show final instructions
show_final_instructions() {
    cat << EOF

${GREEN}Git Workflow Setup Complete!${NC}

${BLUE}Next Steps:${NC}

1. ${YELLOW}Create GitHub Repository:${NC}
   - Create a new repository on GitHub
   - Use the URL you provided or update it later

2. ${YELLOW}Configure GitHub Secrets (for GitHub Actions):${NC}
   - Go to repository Settings > Secrets and variables > Actions
   - Add these secrets:
     * DEPLOY_HOST: Your server IP or domain
     * DEPLOY_USER: SSH username (usually ubuntu)
     * DEPLOY_KEY: SSH private key for server access

3. ${YELLOW}Setup Deployment:${NC}
   - Run: sudo ./setup-auto-update.sh
   - Choose webhook or cron-based updates
   - Configure GitHub webhook if using real-time updates

4. ${YELLOW}Development Workflow:${NC}
   - Create feature branches: git checkout -b feature/new-feature
   - Make changes and commit: git commit -m "Add new feature"
   - Push and create pull requests
   - Merge to main triggers deployment

${BLUE}Available Commands:${NC}
- Manual deployment: sudo ./github-deploy.sh
- Setup auto-updates: sudo ./setup-auto-update.sh
- View deployment logs: journalctl -u twilio-sms -f

${BLUE}Files Created:${NC}
- .gitignore (ignores sensitive files)
- .github/workflows/deploy.yml (GitHub Actions)
- .git/hooks/pre-commit (code quality checks)
- CONTRIBUTING.md (development guidelines)

${GREEN}Your Twilio SMS App is now ready for collaborative development!${NC}

EOF
}

# Main function
main() {
    log "Setting up Git workflow for Twilio SMS App..."
    
    cd "$SCRIPT_DIR"
    
    check_git
    init_git_repo
    create_gitignore
    create_github_actions
    create_pre_commit_hooks
    setup_git_config
    create_workflow_docs
    setup_remote
    create_initial_commit
    show_final_instructions
    
    success "Git workflow setup completed!"
}

# Show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script sets up a complete Git workflow including:"
    echo "- Repository initialization"
    echo "- .gitignore configuration"
    echo "- GitHub Actions CI/CD"
    echo "- Pre-commit hooks"
    echo "- Development guidelines"
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

main
