#!/bin/bash
# Installation script for EC2 instance prerequisites
# Supports Amazon Linux 2, Amazon Linux 2023, and Ubuntu

set -e

echo "========================================="
echo "Installing Prerequisites for EC2 Instance"
echo "========================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    echo "Cannot detect OS. Assuming Amazon Linux 2"
    OS="amzn"
fi

echo "Detected OS: $OS $OS_VERSION"

# Update system packages
echo ""
echo "Updating system packages..."
if [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
    sudo yum update -y
elif [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    sudo apt-get update -y
    sudo apt-get upgrade -y
fi

# Install jq
echo ""
echo "Installing jq..."
if [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
    sudo yum install -y jq
elif [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    sudo apt-get install -y jq
fi

# Verify jq installation
if command -v jq &> /dev/null; then
    echo "✓ jq installed: $(jq --version)"
else
    echo "✗ jq installation failed"
    exit 1
fi

# Install Docker
echo ""
echo "Installing Docker..."
if [ "$OS" == "amzn" ]; then
    # Amazon Linux 2
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -a -G docker $USER
elif [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    # Ubuntu/Debian
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -a -G docker $USER
fi

# Verify Docker installation
if command -v docker &> /dev/null; then
    echo "✓ Docker installed: $(docker --version)"
    echo "  Note: You may need to log out and back in for Docker group changes to take effect"
else
    echo "✗ Docker installation failed"
    exit 1
fi

# Install Node.js (v20) and npm
echo ""
echo "Installing Node.js v20 and npm..."
if [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
    # Install NodeSource repository for Amazon Linux/RHEL/CentOS
    curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
    sudo yum install -y nodejs
elif [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    # Install NodeSource repository for Ubuntu/Debian
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Verify Node.js and npm installation
if command -v node &> /dev/null; then
    echo "✓ Node.js installed: $(node --version)"
else
    echo "✗ Node.js installation failed"
    exit 1
fi

if command -v npm &> /dev/null; then
    echo "✓ npm installed: $(npm --version)"
else
    echo "✗ npm installation failed"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    AWS_CLI_ARCH="x86_64"
elif [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
    AWS_CLI_ARCH="aarch64"
else
    echo "✗ Unsupported architecture: $ARCH"
    exit 1
fi

echo "Detected architecture: $ARCH"

# Install AWS CLI v2
echo ""
echo "Installing AWS CLI v2..."
if command -v aws &> /dev/null; then
    # Check if AWS CLI is executable (might be wrong architecture)
    if aws --version &> /dev/null; then
        CURRENT_VERSION=$(aws --version | awk '{print $1}' | cut -d'/' -f2 | cut -d'.' -f1)
        if [ "$CURRENT_VERSION" -ge 2 ]; then
            echo "✓ AWS CLI v2 already installed: $(aws --version)"
            SKIP_AWS_INSTALL=true
        else
            echo "AWS CLI v1 detected. Installing v2..."
            SKIP_AWS_INSTALL=false
        fi
    else
        echo "AWS CLI found but not executable (wrong architecture?). Reinstalling..."
        SKIP_AWS_INSTALL=false
    fi
    
    if [ "$SKIP_AWS_INSTALL" != "true" ]; then
        # Remove existing AWS CLI installation
        if [ -d "/usr/local/aws-cli" ]; then
            sudo rm -rf /usr/local/aws-cli
        fi
        if [ -d "/usr/local/bin/aws" ]; then
            sudo rm -f /usr/local/bin/aws
        fi
        if [ -d "/usr/local/bin/aws_completer" ]; then
            sudo rm -f /usr/local/bin/aws_completer
        fi
        
        # Remove v1 if exists
        if [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
            sudo yum remove -y awscli 2>/dev/null || true
        elif [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
            sudo apt-get remove -y awscli 2>/dev/null || true
        fi
        
        # Install v2 for correct architecture
        cd /tmp
        curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf awscliv2.zip aws/
        cd -
    fi
else
    # Install AWS CLI v2
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
    cd -
fi

# Verify AWS CLI installation
if command -v aws &> /dev/null; then
    echo "✓ AWS CLI installed: $(aws --version)"
    echo "  Note: Run 'aws configure' to set up credentials"
else
    echo "✗ AWS CLI installation failed"
    exit 1
fi

# Install unzip (required for AWS CLI installation on some systems)
echo ""
echo "Installing unzip (if not already installed)..."
if [ "$OS" == "amzn" ] || [ "$OS" == "rhel" ] || [ "$OS" == "centos" ]; then
    sudo yum install -y unzip
elif [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    sudo apt-get install -y unzip
fi

# Summary
echo ""
echo "========================================="
echo "Installation Summary"
echo "========================================="
echo "jq:        $(jq --version 2>/dev/null || echo 'Not installed')"
echo "Docker:    $(docker --version 2>/dev/null || echo 'Not installed')"
echo "Node.js:   $(node --version 2>/dev/null || echo 'Not installed')"
echo "npm:       $(npm --version 2>/dev/null || echo 'Not installed')"
echo "AWS CLI:   $(aws --version 2>/dev/null || echo 'Not installed')"
echo ""
echo "========================================="
echo "Next Steps:"
echo "========================================="
echo "1. Configure AWS CLI: aws configure"
echo "2. If Docker group was added, log out and log back in: exit && ssh back in"
echo "3. Verify Docker works: docker ps"
echo "4. Clone the repository and run: npm install"
echo "========================================="

