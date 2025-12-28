# 🚀 **QUICK DEPLOYMENT COMMANDS - Ubuntu 24.04**

## **📋 Required Package List**

```bash
# Essential system packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    curl wget git unzip software-properties-common \
    python3 python3-pip python3-venv python3-dev \
    build-essential libssl-dev libffi-dev libsqlite3-dev \
    nginx supervisor ufw fail2ban htop nano vim
```

## **⚡ One-Command Deployment**

```bash
# 1. Connect to EC2
ssh -i "your-key-pair.pem" ubuntu@your-ec2-public-ip

# 2. Run complete setup (copy/paste this entire block)
sudo apt update && sudo apt upgrade -y && \
sudo apt install -y curl wget git unzip software-properties-common python3 python3-pip python3-venv python3-dev build-essential libssl-dev libffi-dev libsqlite3-dev nginx supervisor ufw fail2ban htop nano vim && \
sudo mkdir -p /opt/twilio-sms-app && \
cd /opt/twilio-sms-app
```

## **📁 Upload Application Files**

**Method 1: Direct Upload (from your Mac)**
```bash
# From your local terminal
scp -i "your-key-pair.pem" -r /Users/hmali/Documents/GitHub/TiwlioSMS/* ubuntu@YOUR_EC2_IP:~/app-files/

# Then on EC2
sudo mv ~/app-files/* /opt/twilio-sms-app/
sudo chown -R ubuntu:ubuntu /opt/twilio-sms-app
```

**Method 2: Manual File Creation**
```bash
# On EC2 instance - create each file manually
cd /opt/twilio-sms-app
# Copy content from your local files to create:
# app.py, requirements.txt, gunicorn_config.py, templates/, static/, etc.
```

## **🚀 Deploy & Start Application**

```bash
# Navigate to app directory
cd /opt/twilio-sms-app

# Create virtual environment and install packages
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create directories
mkdir -p uploads logs
sudo mkdir -p /var/log/twilio-sms-app

# Initialize database
python3 -c "from app import init_db; init_db()"

# Set permissions
sudo chown -R www-data:www-data /opt/twilio-sms-app
sudo chmod -R 755 /opt/twilio-sms-app

# Create systemd service
sudo tee /etc/systemd/system/twilio-sms-app.service > /dev/null << 'EOF'
[Unit]
Description=Twilio SMS Bulk Application
After=network.target

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=/opt/twilio-sms-app
Environment="PATH=/opt/twilio-sms-app/venv/bin"
ExecStart=/opt/twilio-sms-app/venv/bin/gunicorn --config gunicorn_config.py app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
sudo tee /etc/nginx/sites-available/twilio-sms-app > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    client_max_body_size 16M;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60;
        proxy_send_timeout 60;
        proxy_read_timeout 60;
    }
    
    location /static {
        alias /opt/twilio-sms-app/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable site and disable default
sudo ln -sf /etc/nginx/sites-available/twilio-sms-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx config
sudo nginx -t

# Configure firewall
sudo ufw --force enable
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'

# Start services
sudo systemctl daemon-reload
sudo systemctl enable twilio-sms-app
sudo systemctl start twilio-sms-app
sudo systemctl enable nginx
sudo systemctl restart nginx
```

## **✅ Verify Installation**

```bash
# Check service status
sudo systemctl status twilio-sms-app
sudo systemctl status nginx

# Get public IP
curl -s http://169.254.169.254/latest/meta-data/public-ipv4

# Test application
curl -I http://localhost
```

## **🌐 Access Application**

1. **Open browser:** `http://YOUR_EC2_PUBLIC_IP`
2. **Login:** `admin` / `admin123`
3. **Configure Twilio credentials in Settings**

## **🛠️ Common Management Commands**

```bash
# Service management
sudo systemctl restart twilio-sms-app
sudo systemctl status twilio-sms-app

# View logs
sudo journalctl -u twilio-sms-app -f
sudo tail -f /var/log/twilio-sms-app/error.log

# Test manually
cd /opt/twilio-sms-app && source venv/bin/activate && python3 app.py
```

## **🔧 Troubleshooting**

### Application won't start:
```bash
sudo journalctl -u twilio-sms-app -n 50
cd /opt/twilio-sms-app && source venv/bin/activate && python3 app.py
```

### Permission issues:
```bash
sudo chown -R www-data:www-data /opt/twilio-sms-app
sudo chmod -R 755 /opt/twilio-sms-app
```

### Database issues:
```bash
cd /opt/twilio-sms-app && source venv/bin/activate
python3 -c "from app import init_db; init_db()"
```

### Port 80 in use:
```bash
sudo systemctl stop apache2
sudo systemctl disable apache2
sudo systemctl restart nginx
```

---

**📞 Ready to use!** Your Twilio Bulk SMS application should now be running at `http://YOUR_EC2_PUBLIC_IP`
