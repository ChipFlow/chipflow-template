#!/bin/bash

set -e

echo "🔄 Updating ChipFlow development environment..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Update PDM if it exists
if command -v pdm &> /dev/null; then
    echo "🐍 Updating PDM..."
    pdm self update
    
    # Update project dependencies if pyproject.toml exists
    if [ -f "pyproject.toml" ]; then
        echo "📚 Updating Python dependencies..."
        pdm update
    fi
fi

# Update VS Code extensions
if command -v code &> /dev/null; then
    echo "🎨 Updating VS Code extensions..."
    code --update-extensions
fi

echo "✅ Environment update complete!"