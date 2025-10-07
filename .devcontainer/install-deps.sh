#!/bin/bash

set -e

echo "📦 Installing ChipFlow dependencies (runs during prebuild)..."

# Verify PDM is available
pdm --version

# Install project dependencies if pyproject.toml exists
if [ -f "pyproject.toml" ]; then
    echo "📚 Installing Python dependencies with PDM (creates venv)..."
    pdm install --dev
    echo "✅ Dependencies installed in $(pdm venv list)"
else
    echo "⚠️  No pyproject.toml found, skipping dependency installation"
fi

# Set up git configuration (minimal)
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global --add safe.directory '*'

echo "✅ Prebuild setup complete!"
