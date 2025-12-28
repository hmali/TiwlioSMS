#!/bin/bash

# Ubuntu 24.04 Package Installation Script for Twilio Bulk SMS App
# Run this script on a fresh Ubuntu 24.04 EC2 instance

set -e

echo "🚀 Installing required packages for Ubuntu 24.04..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo "🔧 Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Python 3.12 and related packages
echo "🐍 Installing Python 3.12 and development tools..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    build-essential \
    libssl-dev \
    libffi-dev \
    libsqlite3-dev

# Install web server and process management
echo "🌐 Installing Nginx and Supervisor..."
sudo apt install -y \
    nginx \
    supervisor

# Install additional utilities
echo "🛠️ Installing additional utilities..."
sudo apt install -y \
    htop \
    nano \
    vim \
    ufw \
    fail2ban \
    logrotate

echo "✅ All packages installed successfully!"
echo "📊 Installed versions:"
python3 --version
pip3 --version
nginx -version
supervisorctl version

echo "🎯 System is ready for Twilio SMS application deployment!"
