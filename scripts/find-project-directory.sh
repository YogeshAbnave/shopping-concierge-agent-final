#!/bin/bash
# Helper script to find the project directory on EC2

echo "Looking for shopping-concierge-agent-final directory..."

# Common locations to check
LOCATIONS=(
    "$HOME"
    "$HOME/shopping-concierge-agent-final"
    "/home/ec2-user/shopping-concierge-agent-final"
    "/opt/shopping-concierge-agent-final"
)

FOUND=false

for location in "${LOCATIONS[@]}"; do
    if [ -f "$location/package.json" ]; then
        echo "✓ Found project directory at: $location"
        echo ""
        echo "To navigate there, run:"
        echo "  cd $location"
        FOUND=true
        break
    fi
done

if [ "$FOUND" = false ]; then
    echo "✗ Project directory not found in common locations"
    echo ""
    echo "Searching home directory for package.json..."
    if [ -f "$HOME/package.json" ]; then
        echo "✓ Found package.json in: $HOME"
        echo "  But this doesn't seem right - you should be in shopping-concierge-agent-final directory"
    else
        echo "✗ No package.json found in $HOME"
        echo ""
        echo "If you haven't cloned the repository yet, you need to:"
        echo "  1. Clone the repository to your EC2 instance"
        echo "  2. Navigate to the cloned directory"
        echo "  3. Then run: npm install"
    fi
fi

