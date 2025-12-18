#!/bin/bash

set -e

# Version info for debugging
TEMPLATE_VERSION="2024-12-17-v5"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 ChipFlow codespace starting..."
echo "   Template version: ${TEMPLATE_VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# disable copilot
cat << EOF > ~/.vscode.settings
{
  "github.copilot.enable": false,
  "github.copilot.inlineSuggest.enable": false,
  "chat.commandCenter.enabled": false,
  "workbench.secondarySideBar.defaultVisibility": "hidden"
}
EOF

# Ensure PDM is in PATH and venv auto-activation is configured
export PATH="/home/user/.local/bin:$PATH"
eval "$(pdm venv activate in-project 2>/dev/null || true)"

# Configurator API base URL (will be set from design config if in codespace)
CONFIGURATOR_API="${CHIPFLOW_CONFIGURATOR_API:-https://configurator.chipflow.io}"

# Check if we're in a codespace and can fetch design from configurator
if [ -n "$CODESPACE_NAME" ]; then
    echo "📡 Fetching design configuration for codespace: $CODESPACE_NAME"

    # Retry logic - sometimes the cache isn't populated yet when post-create runs
    MAX_RETRIES=10
    RETRY_DELAY=3
    HTTP_CODE="404"

#    # Copy uv cache from Docker image (contains Python wheels - 800MB+)
#    echo "🔥 Copying uv cache..."
#    mkdir -p ~/.cache/uv
#    if [ -d /opt/chipflow-cache/uv ] && [ "$(ls -A /opt/chipflow-cache/uv)" ]; then
#          cp -r /opt/chipflow-cache/uv/* ~/.cache/uv/
#        echo "✅ uv cache copied"
#    else
#        echo "⚠️  No uv cache found"
#    fi
#
#    # Copy PDM cache from Docker image
#    echo "🔥 Copying PDM cache..."
#    mkdir -p ~/.cache/pdm
#    if [ -d /opt/chipflow-cache/pdm ] && [ "$(ls -A /opt/chipflow-cache/pdm)" ]; then
#        cp -r /opt/chipflow-cache/pdm/* ~/.cache/pdm/
#        echo "✅ PDM cache copied"
#    else
#        echo "⚠️  No PDM cache found"
#    fi
#    pdm config cache_dir ~/.cache/pdm
#
    # Copy yowasp cache from Docker image
    echo "🔥 Synchronizing caches..."
    if [ -d /opt/chipflow-cache/yowasp ] && [ "$(ls -A /opt/chipflow-cache/yowasp)" ]; then
        mkdir -p ~/.cache/YoWASP
        rsync -tr /opt/chipflow-cache/yowasp/* ~/.cache/YoWASP/ && echo "  ✅ yowasp-yosys cache copied"
    else
        echo "  ⚠️  No yowasp cache found"
    fi

    # Copy zig cache from Docker image
    if [ -d /opt/chipflow-cache/zig ] && [ "$(ls -A /opt/chipflow-cache/zig)" ]; then
        mkdir -p ~/.cache/zig
        rsync -tr /opt/chipflow-cache/zig/* ~/.cache/zig/ && echo "  ✅ zig cache copied"
    else
        echo "  ⚠️  No zig cache found"
    fi


    for attempt in $(seq 1 $MAX_RETRIES); do
        echo "Attempt $attempt/$MAX_RETRIES..."

        # Try to fetch design from configurator API
        DESIGN_RESPONSE=$(curl -s -w "\n%{http_code}" "${CONFIGURATOR_API}/api/design/${CODESPACE_NAME}")
        HTTP_CODE=$(echo "$DESIGN_RESPONSE" | tail -n1)
        DESIGN_BODY=$(echo "$DESIGN_RESPONSE" | sed '$d')

        if [ "$HTTP_CODE" = "200" ]; then
            break
        fi

        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "Design not ready yet (HTTP $HTTP_CODE), waiting ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        fi
    done

    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Design configuration found"

        # Save design.json
        echo "$DESIGN_BODY" | jq -r '.designData' > design.json

        # Extract config from response (contains configuratorApi and welcomeUrl)
        CHIPFLOW_CONFIGURATOR_API=$(echo "$DESIGN_BODY" | jq -r '.config.configuratorApi // "https://configurator.chipflow.io"')
        CHIPFLOW_WELCOME_URL=$(echo "$DESIGN_BODY" | jq -r '.config.welcomeUrl // empty')

        # Export to current environment
        export CHIPFLOW_CONFIGURATOR_API
        export CHIPFLOW_WELCOME_URL

        # Update CONFIGURATOR_API with value from config
        CONFIGURATOR_API="$CHIPFLOW_CONFIGURATOR_API"

        # Save to .env file for sourcing by new terminals
        cat > ~/.chipflow.env << EOF
export CHIPFLOW_CONFIGURATOR_API="$CHIPFLOW_CONFIGURATOR_API"
export CHIPFLOW_WELCOME_URL="$CHIPFLOW_WELCOME_URL"
EOF

        # Source the env file from bashrc if not already done
        if ! grep -q "source ~/.chipflow.env" ~/.bashrc 2>/dev/null; then
            echo "" >> ~/.bashrc
            echo "# ChipFlow configuration (auto-generated)" >> ~/.bashrc
            echo "if [ -f ~/.chipflow.env ]; then source ~/.chipflow.env; fi" >> ~/.bashrc
        fi

        # Source immediately for current session
        source ~/.chipflow.env

        # Fetch generated files from API
        echo "🔨 Generating design files..."
        FILES_RESPONSE=$(curl -s -X POST "${CONFIGURATOR_API}/api/design/generate" \
            -H "Content-Type: application/json" \
            -d "{\"designData\": $(cat design.json)}")

        if echo "$FILES_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
            # Create directories
            mkdir -p design/software design/steps design/tests

            # Extract and save each file
            # Use process substitution instead of pipe to avoid subshell issues
            while read -r file; do
                FILE_PATH=$(echo "$file" | jq -r '.path')
                FILE_DIR=$(dirname "$FILE_PATH")
                mkdir -p "$FILE_DIR"

                # Force overwrite the file
                echo "$file" | jq -r '.content' > "$FILE_PATH"

                # Verify the file was written
                if [ -f "$FILE_PATH" ]; then
                    FILE_SIZE=$(wc -c < "$FILE_PATH")
                    echo "  ✓ $FILE_PATH (${FILE_SIZE} bytes)"
                else
                    echo "  ✗ Failed to write $FILE_PATH"
                fi
            done < <(echo "$FILES_RESPONSE" | jq -r '.files[] | @json')

            echo "✅ Design files generated successfully"

            # Generate pins.lock file
            echo "🔧 Generating pins.lock..."
            if chipflow pin lock > /dev/null 2>&1; then
                echo "✅ pins.lock generated"
            else
                echo "⚠️  Failed to generate pins.lock (will be created on first build)"
            fi
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

# Fetch and display configurator version
CONFIGURATOR_VERSION=$(curl -s "${CONFIGURATOR_API}/api/version" 2>/dev/null | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 Getting Started"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   The ChipFlow Welcome panel should open automatically."
echo "   If not, press Cmd/Ctrl+Shift+P and run 'ChipFlow: Show Welcome'"
echo ""
echo "   Versions:"
echo "   • Template: ${TEMPLATE_VERSION}"
echo "   • Configurator: ${CONFIGURATOR_VERSION}"
echo ""
echo "   Extensions:"
if command -v code &>/dev/null; then
    if code --list-extensions 2>/dev/null | grep -q "chipflow"; then
        echo "   ✅ ChipFlow Workbench extension installed"
    else
        echo "   ⚠️  ChipFlow Workbench extension not found"
        echo "   Installing now..."
        if [ -f ".devcontainer/extensions/chipflow-workbench-latest.vsix" ]; then
            code --install-extension .devcontainer/extensions/chipflow-workbench-latest.vsix --force 2>/dev/null && echo "   ✅ Extension installed" || echo "   ❌ Installation failed"
        else
            echo "   ❌ Extension file not found"
        fi
    fi
else
    echo "   ⚠️  VS Code CLI not available yet"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Quick commands:"
echo "  • F5 or Cmd/Ctrl+Shift+B - Build and run simulation"
echo "  • chipflow --help - ChipFlow CLI help"
echo "  • pdm run --list - See all available commands"
echo ""
echo "Entering venv:"
pdm config check_update false
eval $(pdm venv activate)
