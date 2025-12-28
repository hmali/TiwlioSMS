#!/usr/bin/env python3

"""
Test script for Twilio Bulk SMS Application
Run this script to verify the application setup
"""

import sys
import os
import subprocess
import sqlite3

def test_python_version():
    """Test Python version compatibility"""
    version = sys.version_info
    print(f"Python version: {version.major}.{version.minor}.{version.micro}")
    
    if version.major == 3 and version.minor >= 8:
        print("✅ Python version is compatible")
        return True
    else:
        print("❌ Python 3.8+ required")
        return False

def test_dependencies():
    """Test if all required packages are installed"""
    required_packages = [
        'flask', 'twilio', 'werkzeug', 'gunicorn', 'jinja2'
    ]
    
    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
            print(f"✅ {package} is installed")
        except ImportError:
            print(f"❌ {package} is missing")
            missing_packages.append(package)
    
    return len(missing_packages) == 0

def test_database():
    """Test database initialization"""
    try:
        from app import init_db
        init_db()
        print("✅ Database initialization successful")
        
        # Test database connection
        conn = sqlite3.connect('twilio_sms.db')
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM users")
        user_count = cursor.fetchone()[0]
        conn.close()
        
        print(f"✅ Database connected, {user_count} users found")
        return True
    except Exception as e:
        print(f"❌ Database error: {str(e)}")
        return False

def test_app_import():
    """Test if the Flask app can be imported"""
    try:
        from app import app
        print("✅ Flask application imported successfully")
        
        # Test basic routes
        with app.test_client() as client:
            response = client.get('/')
            print(f"✅ Root route accessible (status: {response.status_code})")
        
        return True
    except Exception as e:
        print(f"❌ App import error: {str(e)}")
        return False

def test_directories():
    """Test if required directories exist"""
    required_dirs = ['templates', 'static', 'static/css', 'static/js', 'uploads']
    all_exist = True
    
    for dir_name in required_dirs:
        if os.path.exists(dir_name):
            print(f"✅ Directory '{dir_name}' exists")
        else:
            print(f"❌ Directory '{dir_name}' missing")
            all_exist = False
    
    return all_exist

def test_configuration_files():
    """Test if configuration files exist"""
    required_files = [
        'app.py', 'requirements.txt', 'gunicorn_config.py',
        'templates/base.html', 'templates/login.html',
        'static/css/style.css', 'static/js/app.js'
    ]
    
    all_exist = True
    for file_name in required_files:
        if os.path.exists(file_name):
            print(f"✅ File '{file_name}' exists")
        else:
            print(f"❌ File '{file_name}' missing")
            all_exist = False
    
    return all_exist

def main():
    """Run all tests"""
    print("🧪 Testing GMADP Application Setup")
    print("=" * 50)
    
    tests = [
        ("Python Version", test_python_version),
        ("Required Packages", test_dependencies),
        ("Directory Structure", test_directories),
        ("Configuration Files", test_configuration_files),
        ("Database", test_database),
        ("Flask Application", test_app_import),
    ]
    
    passed_tests = 0
    total_tests = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🔍 Testing: {test_name}")
        print("-" * 30)
        
        try:
            if test_func():
                passed_tests += 1
                print(f"✅ {test_name}: PASSED")
            else:
                print(f"❌ {test_name}: FAILED")
        except Exception as e:
            print(f"❌ {test_name}: ERROR - {str(e)}")
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed_tests}/{total_tests} tests passed")
    
    if passed_tests == total_tests:
        print("🎉 All tests passed! Application is ready to deploy.")
        print("\n🚀 Next steps:")
        print("   1. Run: python3 app.py (for development)")
        print("   2. Or: gunicorn -c gunicorn_config.py app:app (for production)")
        print("   3. Configure Nginx reverse proxy")
        print("   4. Set up systemd service")
        return True
    else:
        print("❌ Some tests failed. Please fix the issues before deployment.")
        print("\n🔧 Common fixes:")
        print("   - Install missing packages: pip install -r requirements.txt")
        print("   - Create missing directories: mkdir -p uploads static/css static/js")
        print("   - Check file permissions")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
