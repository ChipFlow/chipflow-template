FROM mcr.microsoft.com/devcontainers/base:alpine-3.20

# Install minimal dependencies - PDM will handle Python environment
RUN apk add --no-cache \
    bash \
    build-base \
    curl \
    git \
    github-cli \
    jq \
    libgcc \
    libstdc++ \
    linux-headers \
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

# Create cache directories as root, then give ownership to user
RUN mkdir -p /opt/chipflow-cache && \
    chown -R user:user /opt/chipflow-cache

COPY first-run-notice.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt

# Switch to user
USER user
WORKDIR /home/user

# Install and setup PDM for user
ENV PATH="/home/user/.local/bin:$PATH"
ENV PDM_VENV_IN_PROJECT=1

# Copy cache-warming design (as user, before RUN so it's in the image)
COPY --chown=user:user cache-warming /home/user/cache-warming-temp

RUN --mount=type=bind,target=/src \
    curl -sSL https://pdm-project.org/install-pdm.py | python3 - && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    echo 'export PATH="/home/user/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pdm venv activate in-project 2>/dev/null || true)"' >> ~/.bashrc && \
    cp /src/pyproject.toml . && \
    cp /src/pdm.lock . && \
    pdm config use_uv true && \
    mkdir -p /opt/chipflow-cache/pdm /opt/chipflow-cache/yowasp /opt/chipflow-cache/zig && \
    pdm config cache_dir /opt/chipflow-cache/pdm && \
    export YOWASP_CACHE_DIR=/opt/chipflow-cache/yowasp && \
    export ZIG_GLOBAL_CACHE_DIR=/opt/chipflow-cache/zig && \
    echo python $(python --version) && \
    echo PDM Config && \
    pdm -vv config && \
    echo PDM install && \
    pdm -vv -n install && \
    pdm config check_update false && \
    echo "Warming yowasp-yosys cache" && \
    pdm run yowasp-yosys --version && \
    echo "Warming zig cache" && \
    cd cache-warming-temp && \
    pdm run chipflow pin lock && \
    pdm run chipflow sim build && \
    cd .. && \
    rm -rf cache-warming-temp
