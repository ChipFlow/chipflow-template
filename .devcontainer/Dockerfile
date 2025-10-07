FROM mcr.microsoft.com/devcontainers/base:alpine-3.20

# Install minimal dependencies - PDM will handle Python environment
RUN apk add --no-cache \
    bash \
    git \
    curl \
    build-base \
    python3 \
    python3-dev \
    py3-pip \
    nodejs \
    npm \
    jq \
    sudo \
    shadow

# Create vscode user with sudo access
RUN addgroup -g 1000 vscode && \
    adduser -D -u 1000 -G vscode -s /bin/bash vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

# Switch to vscode user
USER vscode
WORKDIR /home/vscode

# Install PDM for vscode user
RUN curl -sSL https://pdm-project.org/install-pdm.py | python3 - && \
    echo 'export PATH="/home/vscode/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pdm venv activate in-project 2>/dev/null || true)"' >> ~/.bashrc

# Set PDM to use in-project venv by default
ENV PDM_VENV_IN_PROJECT=1
ENV PATH="/home/vscode/.local/bin:$PATH"
