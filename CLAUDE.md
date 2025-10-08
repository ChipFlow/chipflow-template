# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The ChipFlow Template is a GitHub repository template used to create ChipFlow projects via GitHub Codespaces. It provides:

- **GitHub Codespaces devcontainer** with Alpine Linux base
- **Pre-configured development environment** with PDM, Python, and ChipFlow tools
- **Automated setup scripts** that fetch design configurations from the configurator API
- **VS Code tasks and launch configurations** for building and running simulations

## Important: Testing Before Commits

**ALWAYS test the devcontainer build before committing changes to `.devcontainer/Dockerfile`:**

```bash
cd .devcontainer
make test    # Builds the Docker image to verify it works
make clean   # Removes test image and build cache
```

If the build fails, fix the Dockerfile before committing. A broken Dockerfile will prevent users from launching codespaces.

## Directory Structure

```
chipflow-template/
├── .devcontainer/
│   ├── Dockerfile           # Alpine-based container with PDM, Python, tools
│   ├── devcontainer.json    # VS Code devcontainer configuration
│   ├── post-create.sh       # Runs when codespace opens (fetches design from API)
│   ├── install-deps.sh      # Runs during prebuild (installs Python deps)
│   ├── first-run-notice.txt # Welcome message for codespace users
│   └── Makefile            # Testing utilities for developers
├── .vscode/
│   ├── tasks.json          # VS Code tasks (build, run simulation)
│   └── launch.json         # Run/Debug configurations (F5)
├── design/                  # ChipFlow design files (generated)
├── scripts/                 # Helper scripts
├── pyproject.toml          # Python dependencies (PDM)
├── pdm.lock               # Locked dependencies
└── chipflow.toml          # ChipFlow configuration
```

## Key Files

### `.devcontainer/Dockerfile`
- Alpine Linux 3.20 base image
- Installs system packages, PDM, UV
- Creates `user` account (uid 1100)
- Pre-installs Python dependencies during prebuild (cached!)
- Uses `--mount=type=bind,target=/src` for build context

**Before committing changes:** Run `make test` in `.devcontainer/`

### `.devcontainer/post-create.sh`
- Runs when codespace opens (after prebuild)
- Checks for `$CODESPACE_NAME` environment variable
- Fetches design JSON from configurator API: `GET /api/design/$CODESPACE_NAME`
- Generates design files via API: `POST /api/design/generate`
- Saves files to workspace
- Graceful fallback to template defaults if no design found

### `.devcontainer/install-deps.sh`
- Runs during prebuild (cached!)
- Installs Python dependencies with PDM
- Git configuration setup

## Development Commands

```bash
# Build and test devcontainer
cd .devcontainer
make test              # Build Docker image
make clean             # Remove test artifacts

# Python development (inside codespace)
chipflow sim build     # Build simulation
chipflow sim run       # Run simulation
chipflow build         # Generate Verilog

# VS Code shortcuts (inside codespace)
F5                     # Run/Debug: Build and run simulation
Cmd/Ctrl+Shift+B       # Run default build task
```

## Design Generation Flow

1. User configures chip in web app at https://configurator.chipflow.io
2. User clicks "Generate & Simulate"
3. Configurator creates codespace via GitHub API
4. Configurator stores design in cache: `cache.set(codespace.name, designData)`
5. Codespace starts, post-create.sh runs
6. Script fetches design: `GET /api/design/$CODESPACE_NAME`
7. Script generates files: `POST /api/design/generate`
8. User has ready-to-run ChipFlow project

## Environment Variables

Available in GitHub Codespaces:
- `CODESPACE_NAME` - Unique codespace identifier (e.g., "octocat-space-parakeet-mld5")
- `CODESPACES` - Always "true" in a codespace
- `CHIPFLOW_CONFIGURATOR_API` - Override configurator API URL (defaults to https://configurator.chipflow.io)

## Docker Build Context

The Dockerfile uses a bind mount for the build context:
```dockerfile
RUN --mount=type=bind,target=/src \
    cp /src/pyproject.toml . && \
    cp /src/pdm.lock . && \
    pdm install
```

This allows the Dockerfile to access files from the parent directory during build.

## Related Repositories

- `configurator/` - Next.js web app for chip configuration
- `chipflow-digital-ip/` - Digital IP block definitions
- `chipflow-examples/` - Example designs
