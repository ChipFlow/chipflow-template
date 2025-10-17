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
    echo "🔥 Copying yowasp-yosys cache..."
    mkdir -p ~/.cache/YoWASP
    if [ -d /opt/chipflow-cache/yowasp ] && [ "$(ls -A /opt/chipflow-cache/yowasp)" ]; then
        cp -rf /opt/chipflow-cache/yowasp/* ~/.cache/YoWASP/
        echo "✅ yowasp-yosys cache copied"
    else
        echo "⚠️  No yowasp cache found"
    fi

    # Copy zig cache from Docker image
    echo "🔥 Copying zig cache..."
    mkdir -p ~/.cache/zig
    if [ -d /opt/chipflow-cache/zig ] && [ "$(ls -A /opt/chipflow-cache/zig)" ]; then
        cp -rf /opt/chipflow-cache/zig/* ~/.cache/zig/
        echo "✅ zig cache copied"
    else
        echo "⚠️  No zig cache found"
    fi

    echo "✅ Fixing cache permissions"
    chmod -R u+w ~/.cache

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
echo "Quick commands:"
echo "  • F5 or Cmd/Ctrl+Shift+B - Build and run simulation"
echo "  • chipflow --help - ChipFlow CLI help"
echo "  • pdm run --list - See all available commands"
echo ""
echo "Entering venv:"
pdm config check_update false
eval $(pdm venv activate)
cat .devcontainer/first-run-notice.txt
