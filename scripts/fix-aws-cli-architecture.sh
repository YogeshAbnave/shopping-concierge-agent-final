#!/bin/bash
# Quick fix script for AWS CLI architecture mismatch
# This removes the incorrectly installed AWS CLI and reinstalls it for the correct architecture

set -e

echo "========================================="
echo "Fixing AWS CLI Architecture Mismatch"
echo "========================================="

# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

if [ "$ARCH" == "x86_64" ]; then
    AWS_CLI_ARCH="x86_64"
elif [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
    AWS_CLI_ARCH="aarch64"
else
    echo "✗ Unsupported architecture: $ARCH"
    exit 1
fi

echo "Will install AWS CLI for: $AWS_CLI_ARCH"
echo ""

# Remove existing AWS CLI installation
echo "Removing existing AWS CLI installation..."
sudo rm -rf /usr/local/aws-cli /usr/local/bin/aws /usr/local/bin/aws_completer 2>/dev/null || true

# Remove via package manager if installed
if command -v yum &> /dev/null; then
    sudo yum remove -y awscli 2>/dev/null || true
elif command -v apt-get &> /dev/null; then
    sudo apt-get remove -y awscli 2>/dev/null || true
fi

# Ensure unzip is installed
if ! command -v unzip &> /dev/null; then
    echo "Installing unzip..."
    if command -v yum &> /dev/null; then
        sudo yum install -y unzip
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y unzip
    fi
fi

# Install AWS CLI v2 for correct architecture
echo ""
echo "Installing AWS CLI v2 for $AWS_CLI_ARCH..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/
cd -

# Verify installation
echo ""
echo "Verifying installation..."
if command -v aws &> /dev/null; then
    echo "✓ AWS CLI installed successfully!"
    aws --version
    echo ""
    echo "Next step: Run 'aws configure' to set up your credentials"
else
    echo "✗ AWS CLI installation failed"
    exit 1
fi

