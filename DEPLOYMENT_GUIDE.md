# 🚀 Complete Deployment Guide - Twilio Bulk SMS App on Ubuntu 24.04

## 📋 **Required Packages List**

### Core System Packages:
```bash
# System updates and essential tools
apt update && apt upgrade -y
apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Python and development tools
apt install -y python3 python3-pip python3-venv python3-dev python3-setuptools build-essential libssl-dev libffi-dev libsqlite3-dev

# Web server and process management
apt install -y nginx supervisor

# Security and monitoring tools
apt install -y ufw fail2ban htop nano vim logrotate
```

### Python Packages (from requirements.txt):
```
Flask==2.3.3
Werkzeug==2.3.7
twilio==8.10.0
python-dotenv==1.0.0
gunicorn==21.2.0
Jinja2==3.1.2
MarkupSafe==2.1.3
itsdangerous==2.1.2
click==8.1.7
blinker==1.6.3
```

## 🎯 **Step-by-Step Deployment**

### **Step 1: Launch & Configure EC2 Instance**

1. **Create EC2 Instance:**
   - AMI: **Ubuntu Server 24.04 LTS (HVM), SSD Volume Type**
   - Instance Type: **t3.medium** (2 vCPU, 4 GB RAM) - recommended
   - Storage: **20 GB gp3** (minimum)
   - Key Pair: Create or select existing

2. **Security Group Configuration:**
   ```
   Type        Protocol    Port Range    Source
   SSH         TCP         22           Your IP/0.0.0.0/0
   HTTP        TCP         80           0.0.0.0/0
   HTTPS       TCP         443          0.0.0.0/0
   Custom TCP  TCP         8000         127.0.0.1/32 (for debugging)
   ```

3. **Connect to Instance:**
   ```bash
   ssh -i "your-key-pair.pem" ubuntu@your-ec2-public-ip
   ```

### **Step 2: Install Required Packages**

**Method A: Use Installation Script**
```bash
# Download and run the Ubuntu setup script
wget https://raw.githubusercontent.com/your-username/twilio-sms-app/main/ubuntu-setup.sh
chmod +x ubuntu-setup.sh
./ubuntu-setup.sh
```

**Method B: Manual Installation**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git unzip software-properties-common

# Install Python 3.12 and development tools
sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential libssl-dev libffi-dev libsqlite3-dev

# Install web server and process manager
sudo apt install -y nginx supervisor

# Install security and monitoring tools
sudo apt install -y ufw fail2ban htop nano vim
```

### **Step 3: Upload Application Files**

**Method A: Direct Upload (from your local machine)**
```bash
# From your local machine (macOS terminal)
scp -i "your-key-pair.pem" -r /Users/hmali/Documents/GitHub/TiwlioSMS/* ubuntu@your-ec2-public-ip:~/

# Then on EC2 instance
sudo mkdir -p /opt/twilio-sms-app
sudo mv ~/* /opt/twilio-sms-app/
sudo chown -R ubuntu:ubuntu /opt/twilio-sms-app
```

**Method B: Using Git (recommended for updates)**
```bash
# On EC2 instance
sudo mkdir -p /opt/twilio-sms-app
cd /opt/twilio-sms-app
sudo git clone https://github.com/your-username/twilio-sms-app.git .
sudo chown -R ubuntu:ubuntu /opt/twilio-sms-app
```

**Method C: Manual File Creation (if needed)**
```bash
# Create the directory and files manually
sudo mkdir -p /opt/twilio-sms-app
cd /opt/twilio-sms-app
# Then create/copy each file individually
```

### **Step 4: Run Deployment Script**

```bash
# Navigate to application directory
cd /opt/twilio-sms-app

# Make deployment script executable
chmod +x manual-deploy.sh

# Run the deployment script
./manual-deploy.sh
```

### **Step 5: Verify Installation**

1. **Check Services:**
   ```bash
   # Check application service
   sudo systemctl status twilio-sms-app
   
   # Check Nginx
   sudo systemctl status nginx
   
   # Check logs
   sudo journalctl -u twilio-sms-app -f
   ```

2. **Test Application:**
   ```bash
   # Get your public IP
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   
   # Test local connection
   curl -I http://localhost
   ```

3. **Access Web Interface:**
   - Open browser: `http://YOUR_EC2_PUBLIC_IP`
   - Default login: `admin` / `admin123`

### **Step 6: Configure Application**

1. **Login to Web Interface**
2. **Go to Settings Page**
3. **Configure Twilio Credentials:**
   - Account SID: `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Auth Token: `your_auth_token`
4. **Save Configuration**

### **Step 7: Test SMS Functionality**

1. **Create Test Phone Numbers File:**
   ```bash
   # Create a test file with your phone number
   echo "+1234567890" > test_numbers.txt
   ```

2. **Send Test Campaign:**
   - Go to "Send SMS" page
   - Upload test_numbers.txt
   - Enter test message
   - Send campaign

## 🛠️ **Troubleshooting Guide**

### **Common Issues and Solutions:**

1. **Application Won't Start:**
   ```bash
   # Check logs
   sudo journalctl -u twilio-sms-app -n 50
   
   # Check Python virtual environment
   cd /opt/twilio-sms-app
   source venv/bin/activate
   python3 app.py  # Test manually
   ```

2. **Nginx Errors:**
   ```bash
   # Test nginx configuration
   sudo nginx -t
   
   # Check nginx logs
   sudo tail -f /var/log/nginx/error.log
   ```

3. **Permission Issues:**
   ```bash
   # Fix file permissions
   sudo chown -R www-data:www-data /opt/twilio-sms-app
   sudo chmod -R 755 /opt/twilio-sms-app
   ```

4. **Database Issues:**
   ```bash
   # Recreate database
   cd /opt/twilio-sms-app
   source venv/bin/activate
   python3 -c "from app import init_db; init_db()"
   ```

5. **Port 80 Already in Use:**
   ```bash
   # Check what's using port 80
   sudo netstat -tulpn | grep :80
   
   # Stop Apache if running
   sudo systemctl stop apache2
   sudo systemctl disable apache2
   ```

### **Useful Commands:**

```bash
# Service Management
sudo systemctl restart twilio-sms-app
sudo systemctl stop twilio-sms-app
sudo systemctl start twilio-sms-app

# Log Monitoring
sudo journalctl -u twilio-sms-app -f          # Application logs
sudo tail -f /var/log/twilio-sms-app/error.log # Error logs
sudo tail -f /var/log/twilio-sms-app/access.log # Access logs

# Application Management
cd /opt/twilio-sms-app
source venv/bin/activate
python3 app.py  # Run manually for testing

# Database Management
cd /opt/twilio-sms-app && source venv/bin/activate
python3 -c "from app import init_db; init_db()"  # Reinitialize DB
```

## 🔒 **Security Hardening (Optional but Recommended)**

1. **SSL/TLS Setup with Let's Encrypt:**
   ```bash
   # Install Certbot
   sudo apt install certbot python3-certbot-nginx
   
   # Get SSL certificate (replace with your domain)
   sudo certbot --nginx -d yourdomain.com
   ```

2. **Fail2Ban Configuration:**
   ```bash
   # Configure fail2ban for additional security
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

3. **Regular Updates:**
   ```bash
   # Set up automatic security updates
   sudo apt install unattended-upgrades
   sudo dpkg-reconfigure unattended-upgrades
   ```

## 📊 **Performance Monitoring**

1. **System Resources:**
   ```bash
   # Monitor system performance
   htop
   df -h  # Disk usage
   free -h  # Memory usage
   ```

2. **Application Logs:**
   ```bash
   # Monitor application performance
   sudo tail -f /var/log/twilio-sms-app/access.log
   ```

## 🔄 **Backup and Updates**

1. **Database Backup:**
   ```bash
   # Backup SQLite database
   cp /opt/twilio-sms-app/twilio_sms.db /backup/location/twilio_sms_$(date +%Y%m%d).db
   ```

2. **Application Updates:**
   ```bash
   # Pull latest changes (if using git)
   cd /opt/twilio-sms-app
   git pull origin main
   sudo systemctl restart twilio-sms-app
   ```

---

**📞 Support:** If you encounter issues, check the troubleshooting section or review the application logs for detailed error messages.
