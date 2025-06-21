#!/bin/bash
# Quick setup script to make all scripts executable

echo "🔧 Making scripts executable..."

# Make all shell scripts executable
find scripts -name "*.sh" -type f -exec chmod +x {} \;

# Make all Python scripts executable
find scripts -name "*.py" -type f -exec chmod +x {} \;

# Make this script executable too
chmod +x make-executable.sh

echo "✅ All scripts are now executable!"
echo ""
echo "You can now run:"
echo "  ./scripts/setup/install.sh"
