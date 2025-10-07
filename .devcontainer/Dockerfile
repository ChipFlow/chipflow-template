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

# Create user with sudo access
RUN addgroup -g 1000 user && \
    adduser -D -u 1000 -G user -s /bin/bash user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user && \
    chmod 0440 /etc/sudoers.d/user

# Switch to user
USER user
WORKDIR /home/user

# Install PDM for user
RUN curl -sSL https://pdm-project.org/install-pdm.py | python3 - && \
    echo 'export PATH="/home/user/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pdm venv activate in-project 2>/dev/null || true)"' >> ~/.bashrc

# Set PDM to use in-project venv by default
ENV PDM_VENV_IN_PROJECT=1
ENV PATH="/home/user/.local/bin:$PATH"
