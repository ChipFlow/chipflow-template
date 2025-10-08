#!/bin/bash

set -e

echo "🚀 ChipFlow codespace starting..."

# Ensure PDM is in PATH and venv auto-activation is configured
export PATH="/home/user/.local/bin:$PATH"
eval "$(pdm venv activate in-project 2>/dev/null || true)"

# Configurator API base URL (can be overridden via environment)
CONFIGURATOR_API="${CHIPFLOW_CONFIGURATOR_API:-https://configurator.chipflow.io}"

# Check if we're in a codespace and can fetch design from configurator
if [ -n "$CODESPACE_NAME" ]; then
    echo "📡 Fetching design configuration for codespace: $CODESPACE_NAME"

    # Try to fetch design from configurator API
    DESIGN_RESPONSE=$(curl -s -w "\n%{http_code}" "${CONFIGURATOR_API}/api/design/${CODESPACE_NAME}")
    HTTP_CODE=$(echo "$DESIGN_RESPONSE" | tail -n1)
    DESIGN_BODY=$(echo "$DESIGN_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Design configuration found"

        # Save design.json
        echo "$DESIGN_BODY" | jq -r '.designData' > design.json

        # Fetch generated files from API
        echo "🔨 Generating design files..."
        FILES_RESPONSE=$(curl -s -X POST "${CONFIGURATOR_API}/api/design/generate" \
            -H "Content-Type: application/json" \
            -d "{\"designData\": $(cat design.json)}")

        if echo "$FILES_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
            # Create directories
            mkdir -p design/software design/steps design/tests

            # Extract and save each file
            echo "$FILES_RESPONSE" | jq -r '.files[] | @json' | while read -r file; do
                FILE_PATH=$(echo "$file" | jq -r '.path')
                FILE_DIR=$(dirname "$FILE_PATH")
                mkdir -p "$FILE_DIR"
                echo "$file" | jq -r '.content' > "$FILE_PATH"
                echo "  ✓ $FILE_PATH"
            done

            echo "✅ Design files generated successfully"
        else
            echo "⚠️  Failed to generate design files from API"
            echo "   Using template defaults"
        fi
    else
        echo "ℹ️  No design configuration found (HTTP $HTTP_CODE)"
        echo "   Using template defaults"
    fi
else
    echo "ℹ️  Not running in a codespace - using template defaults"
fi

echo ""
echo "🎉 ChipFlow codespace is ready!"
echo ""
if [ -f ".venv/bin/activate" ]; then
    echo "✅ PDM virtual environment is active"
    echo ""
fi
echo "Quick commands:"
echo "  • F5 or Cmd/Ctrl+Shift+B - Build and run simulation"
echo "  • chipflow --help - ChipFlow CLI help"
echo "  • pdm run --list - See all available commands"
echo ""
echo "Entering venv:"
pdm config check_update false
eval $(pdm venv activate)

