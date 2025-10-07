#!/bin/bash

set -e

echo "📦 Installing ChipFlow dependencies (runs during prebuild)..."

# Ensure PDM is in PATH
export PATH="/home/vscode/.local/bin:$PATH"

# Verify PDM is available
if ! command -v pdm &> /dev/null; then
    echo "⚠️  PDM not found, attempting to install..."
    curl -sSL https://pdm-project.org/install-pdm.py | python3 -
    export PATH="/home/vscode/.local/bin:$PATH"
fi

pdm --version

# Install project dependencies if pyproject.toml exists
if [ -f "pyproject.toml" ]; then
    echo "📚 Installing Python dependencies with PDM..."
    pdm install --dev
    echo "✅ Dependencies installed successfully"
else
    echo "⚠️  No pyproject.toml found, skipping dependency installation"
fi

# Set up git configuration (minimal)
git config --global init.defaultBranch main
git config --global pull.rebase false

echo "✅ Prebuild setup complete!"
