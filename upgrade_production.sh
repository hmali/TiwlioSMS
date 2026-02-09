#!/bin/bash
################################################################################
# TwilioSMS Production Upgrade Script
# Version: 2.1.1 Hotfix
# 
# This script safely upgrades your production TwilioSMS application
# with automatic backup, rollback support, and health checks.
#
# Usage:
#   Local:  bash upgrade_production.sh
#   Remote: ssh user@server 'bash -s' < upgrade_production.sh
#
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="${APP_DIR:-$HOME/TiwlioSMS}"
BACKUP_DIR="$APP_DIR/backups"
SERVICE_NAME="twiliosms"
GIT_BRANCH="dev/twilioms-test"
REPO_URL="https://github.com/hmali/TiwlioSMS.git"

# Timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/twilio_sms.db.backup_$TIMESTAMP"
CODE_BACKUP="$BACKUP_DIR/code_backup_$TIMESTAMP"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║        TwilioSMS v2.1.1 Production Upgrade Script             ║"
    echo "║        Safe Deployment with Automatic Rollback                ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✖ $1${NC}"
}

print_info() {
    echo -e "${MAGENTA}ℹ $1${NC}"
}

################################################################################
# Pre-flight Checks
################################################################################

preflight_checks() {
    print_step "Running pre-flight checks..."
    
    # Check if running as correct user
    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run this script as root/sudo!"
        print_info "Run as: bash upgrade_production.sh"
        exit 1
    fi
    
    # Check if application directory exists
    if [ ! -d "$APP_DIR" ]; then
        print_error "Application directory not found: $APP_DIR"
        print_info "Set APP_DIR environment variable if installed elsewhere"
        exit 1
    fi
    
    # Check if database exists
    if [ ! -f "$APP_DIR/twilio_sms.db" ]; then
        print_error "Database not found: $APP_DIR/twilio_sms.db"
        exit 1
    fi
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        print_error "Service not found: $SERVICE_NAME"
        print_info "Install the application first using install_production.sh"
        exit 1
    fi
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        sudo apt install -y git
    fi
    
    # Check internet connectivity
    if ! ping -c 1 github.com &> /dev/null; then
        print_warning "Cannot reach GitHub. Check internet connection."
    fi
    
    print_success "Pre-flight checks passed"
}

################################################################################
# Backup Functions
################################################################################

create_backup() {
    print_step "Creating backups..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Backup database
    print_info "Backing up database..."
    cp "$APP_DIR/twilio_sms.db" "$BACKUP_FILE"
    print_success "Database backed up: $BACKUP_FILE"
    
    # Backup current code
    print_info "Backing up current code..."
    cd "$APP_DIR"
    git stash save "Backup before upgrade $TIMESTAMP" || true
    
    # Get current commit hash for rollback
    CURRENT_COMMIT=$(git rev-parse HEAD)
    echo "$CURRENT_COMMIT" > "$BACKUP_DIR/last_commit_$TIMESTAMP.txt"
    print_success "Code backed up at commit: $CURRENT_COMMIT"
    
    # Backup config files (if any custom configs exist)
    if [ -f "$APP_DIR/.env" ]; then
        cp "$APP_DIR/.env" "$BACKUP_DIR/.env.backup_$TIMESTAMP"
        print_success "Environment file backed up"
    fi
    
    # Show backup summary
    print_info "Backup Summary:"
    echo "  Database: $BACKUP_FILE"
    echo "  Commit:   $CURRENT_COMMIT"
    echo "  Time:     $(date)"
    
    # Keep only last 10 backups
    print_info "Cleaning old backups (keeping last 10)..."
    cd "$BACKUP_DIR"
    ls -t twilio_sms.db.backup_* 2>/dev/null | tail -n +11 | xargs rm -f || true
    print_success "Backup complete"
}

################################################################################
# Service Management
################################################################################

stop_service() {
    print_step "Stopping application service..."
    
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        sudo systemctl stop $SERVICE_NAME
        sleep 2
        
        # Verify service stopped
        if sudo systemctl is-active --quiet $SERVICE_NAME; then
            print_error "Failed to stop service"
            exit 1
        fi
        print_success "Service stopped"
    else
        print_warning "Service was not running"
    fi
}

start_service() {
    print_step "Starting application service..."
    
    sudo systemctl start $SERVICE_NAME
    sleep 3
    
    # Verify service started
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        print_info "Checking logs..."
        sudo journalctl -u $SERVICE_NAME -n 20 --no-pager
        return 1
    fi
}

################################################################################
# Code Update
################################################################################

update_code() {
    print_step "Updating application code..."
    
    cd "$APP_DIR"
    
    # Fetch latest changes
    print_info "Fetching from GitHub..."
    git fetch origin $GIT_BRANCH
    
    # Show what will be updated
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse origin/$GIT_BRANCH)
    
    if [ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]; then
        print_warning "Already up to date (no changes)"
        return 0
    fi
    
    print_info "Changes to be applied:"
    git log --oneline $LOCAL_COMMIT..$REMOTE_COMMIT
    
    # Pull changes
    print_info "Pulling latest code..."
    git pull origin $GIT_BRANCH
    
    print_success "Code updated successfully"
}

################################################################################
# Dependency Update
################################################################################

update_dependencies() {
    print_step "Updating Python dependencies..."
    
    cd "$APP_DIR"
    
    # Activate virtual environment
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
    else
        print_error "Virtual environment not found"
        exit 1
    fi
    
    # Upgrade pip
    print_info "Upgrading pip..."
    pip install --upgrade pip -q
    
    # Install/update dependencies
    print_info "Installing requirements..."
    pip install -r requirements.txt --upgrade -q
    
    print_success "Dependencies updated"
}

################################################################################
# Database Migration
################################################################################

migrate_database() {
    print_step "Running database migration..."
    
    cd "$APP_DIR"
    source venv/bin/activate
    
    # Check if migration script exists
    if [ -f "scripts/migrate_db_v2.1.1.py" ]; then
        print_info "Executing v2.1.1 migration script..."
        python3 scripts/migrate_db_v2.1.1.py
        print_success "v2.1.1 migration complete"
    else
        print_warning "v2.1.1 migration script not found (may not be needed)"
    fi
    
    # Check if intent update script exists (v2.1.2)
    if [ -f "scripts/update_intent_pending.py" ]; then
        print_info "Executing v2.1.2 intent update..."
        python3 scripts/update_intent_pending.py
        print_success "Intent update complete"
    else
        print_warning "Intent update script not found (may not be needed)"
    fi
}

################################################################################
# Permissions & Cleanup
################################################################################

fix_permissions() {
    print_step "Fixing file permissions..."
    
    cd "$APP_DIR"
    
    # Fix ownership
    sudo chown -R $USER:www-data "$APP_DIR"
    
    # Fix directory permissions
    chmod 755 "$APP_DIR"
    
    # Fix database permissions
    if [ -f "twilio_sms.db" ]; then
        chmod 664 twilio_sms.db
    fi
    
    # Fix log file permissions
    if [ -f "twilio_sms.log" ]; then
        chmod 664 twilio_sms.log
    fi
    
    print_success "Permissions fixed"
}

################################################################################
# Health Checks
################################################################################

health_check() {
    print_step "Running health checks..."
    
    # Check 1: Service status
    print_info "1. Checking service status..."
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Service is running"
    else
        print_error "Service is not running"
        return 1
    fi
    
    # Check 2: HTTP response
    print_info "2. Checking HTTP response..."
    sleep 3
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 || echo "000")
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "302" ]; then
        print_success "Application responding (HTTP $HTTP_CODE)"
    else
        print_error "Application not responding (HTTP $HTTP_CODE)"
        return 1
    fi
    
    # Check 3: Database accessible
    print_info "3. Checking database..."
    cd "$APP_DIR"
    if sqlite3 twilio_sms.db "SELECT COUNT(*) FROM users;" &> /dev/null; then
        print_success "Database accessible"
    else
        print_error "Database not accessible"
        return 1
    fi
    
    # Check 4: Python syntax
    print_info "4. Checking Python syntax..."
    source venv/bin/activate
    if python3 -c "import app" 2>/dev/null; then
        print_success "Python code valid"
    else
        print_error "Python syntax errors detected"
        return 1
    fi
    
    # Check 5: Template files exist
    print_info "5. Checking template files..."
    if [ -f "templates/inbound_messages.html" ]; then
        print_success "Templates present"
    else
        print_error "Template files missing"
        return 1
    fi
    
    print_success "All health checks passed ✓"
    return 0
}

################################################################################
# Rollback Function
################################################################################

rollback() {
    print_error "UPGRADE FAILED - Initiating rollback..."
    
    print_step "Rolling back changes..."
    
    # Stop service
    sudo systemctl stop $SERVICE_NAME || true
    
    # Restore database
    if [ -f "$BACKUP_FILE" ]; then
        print_info "Restoring database..."
        cp "$BACKUP_FILE" "$APP_DIR/twilio_sms.db"
        print_success "Database restored"
    fi
    
    # Restore code
    cd "$APP_DIR"
    if [ -f "$BACKUP_DIR/last_commit_$TIMESTAMP.txt" ]; then
        ROLLBACK_COMMIT=$(cat "$BACKUP_DIR/last_commit_$TIMESTAMP.txt")
        print_info "Restoring code to commit: $ROLLBACK_COMMIT"
        git reset --hard $ROLLBACK_COMMIT
        print_success "Code restored"
    fi
    
    # Restore stashed changes
    git stash pop || true
    
    # Fix permissions
    chmod 664 twilio_sms.db
    
    # Start service
    print_info "Restarting service..."
    sudo systemctl start $SERVICE_NAME
    
    print_warning "Rollback complete - System restored to previous state"
    print_info "Check logs: sudo journalctl -u $SERVICE_NAME -n 50"
    
    exit 1
}

################################################################################
# Main Upgrade Process
################################################################################

main() {
    print_header
    
    print_info "Upgrade Details:"
    echo "  Application: TwilioSMS v2.1.1"
    echo "  Directory:   $APP_DIR"
    echo "  Service:     $SERVICE_NAME"
    echo "  Branch:      $GIT_BRANCH"
    echo "  Timestamp:   $(date)"
    echo ""
    
    # Confirmation prompt
    read -p "$(echo -e ${YELLOW}Continue with upgrade? [y/N]:${NC} )" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Upgrade cancelled by user"
        exit 0
    fi
    
    # Set up error handling
    trap rollback ERR
    
    # Execute upgrade steps
    preflight_checks
    create_backup
    stop_service
    update_code
    update_dependencies
    migrate_database
    fix_permissions
    start_service
    
    # Health check with retry
    if ! health_check; then
        print_warning "Health check failed, retrying in 5 seconds..."
        sleep 5
        if ! health_check; then
            rollback
        fi
    fi
    
    # Success!
    print_step "Upgrade Summary"
    echo ""
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║              ✅  UPGRADE COMPLETED SUCCESSFULLY               ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    print_info "What was updated:"
    cd "$APP_DIR"
    git log --oneline -5
    echo ""
    
    print_info "New Features in v2.1.1:"
    echo "  ✅ Custom 1:1 reply to inbound messages"
    echo "  ✅ Enhanced auto-reply with intent detection"
    echo "  ✅ Subscriber management dashboard"
    echo "  ✅ Improved STOP/START compliance"
    echo ""
    
    print_info "Next Steps:"
    echo "  1. Access: http://your-domain.com"
    echo "  2. Login with admin credentials"
    echo "  3. Test Inbound Messages → Reply feature"
    echo "  4. Monitor logs: sudo journalctl -u twiliosms -f"
    echo ""
    
    print_info "Backup Location:"
    echo "  Database: $BACKUP_FILE"
    echo "  All backups: $BACKUP_DIR"
    echo ""
    
    print_success "Upgrade complete! 🎉"
}

################################################################################
# Script Entry Point
################################################################################

# Run main function
main "$@"
