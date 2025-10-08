#!/bin/bash

set -e

# Ensure PDM is in PATH and venv auto-activation is configured
export PATH="/home/vscode/.local/bin:$PATH"
eval "$(pdm venv activate in-project 2>/dev/null || true)"

# Check if design configuration was passed from configurator
if [ -n "$CHIPFLOW_DESIGN_CONFIG" ]; then
    echo "🎨 Generating ChipFlow design from configurator..."

    # Decode and save design configuration
    echo "$CHIPFLOW_DESIGN_CONFIG" | base64 -d > design.json
    echo "✅ Design configuration saved to design.json"

    # Create design directory structure
    mkdir -p design/software design/steps design/tests

    # Use Node.js to generate design.py from design.json
    if [ -f "scripts/generate-design-py.js" ]; then
        node scripts/generate-design-py.js design.json design/design.py \
            && echo "✅ Design files generated successfully" \
            || echo "⚠️  Could not generate design files automatically"
    else
        echo "⚠️  generate-design-py.js not found"
    fi

    # Generate README with design information
    if [ -f "design.json" ]; then
        ACTIVE_CONFIG=$(jq -r '.activeConfigId // "unknown"' design.json)
        ENABLED_BLOCKS=$(jq -r '.enabledBlocks | length' design.json)

        cat > README.md << EOF
# ChipFlow Design

**Generated from configurator**

- **Configuration**: ${ACTIVE_CONFIG}
- **Enabled Blocks**: ${ENABLED_BLOCKS}
- **Generated**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Quick Start

\`\`\`bash
# Build and run simulation
chipflow sim build
chipflow sim run

# Generate Verilog
chipflow build
\`\`\`

## VS Code Tasks

Use the Run/Debug button (F5) or Terminal → Run Task to:
- Build simulation
- Run simulation
- Generate Verilog

## Project Structure

- \`design/design.py\` - Generated Amaranth HDL design
- \`design/software/\` - Embedded software
- \`chipflow.toml\` - ChipFlow configuration
- \`.vscode/\` - VS Code tasks and launch configs
EOF
        echo "✅ README.md generated"
    fi
else
    echo "ℹ️  No design configuration provided - using template defaults"
fi

