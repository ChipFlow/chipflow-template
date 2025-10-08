FROM mcr.microsoft.com/devcontainers/base:alpine-3.20

# Install minimal dependencies - PDM will handle Python environment
RUN apk add --no-cache \
    bash \
    build-base \
    curl \
    git \
    github-cli \
    jq \
    nodejs \
    npm \
    py3-pip \
    python3 \
    python3-dev \
    sudo \
    shadow

# Create user with sudo access
RUN addgroup -g 1100 user && \
    adduser -D -u 1100 -G user -s /bin/bash user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user && \
    chmod 0440 /etc/sudoers.d/user

# Switch to user
USER user
WORKDIR /home/user

# Install and setup PDM for user
ENV PATH="/home/user/.local/bin:$PATH"
ENV PDM_VENV_IN_PROJECT=1
 

RUN --mount=type=bind,target=/src \
    curl -sSL https://pdm-project.org/install-pdm.py | python3 - && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    echo 'export PATH="/home/user/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pdm venv activate in-project 2>/dev/null || true)"' >> ~/.bashrc && \
    cp /src/pyproject.toml . && \
    cp /src/pdm.lock . && \
    echo python $(python --version) && \
    echo PDM Config && \
    pdm -vv config && \
    pdm config use_uv true && \
    echo PDM install && \
    pdm -vv -n install && \
    pdm config check_update false
	
