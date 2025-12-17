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
COPY post-create.sh /usr/local/share/post-create.sh
RUN chmod +x /usr/local/share/post-create.sh

# Switch to user
USER user
WORKDIR /home/user

# Install and setup PDM for user
ENV PATH="/home/user/.local/bin:$PATH"
ENV PDM_VENV_IN_PROJECT=1

# Layer 1: Install PDM and uv (rarely changes)
RUN curl -sSL https://pdm-project.org/install-pdm.py | python3 - && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# Layer 2: Configure shell (rarely changes)
RUN echo 'export PATH="/home/user/.local/bin:$PATH"' >> ~/.bashrc && \
    echo 'export PS1="\W\$ "' >> ~/.bashrc && \
    echo 'eval "$(pdm venv activate in-project 2>/dev/null || true)"' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Run post-create setup once per codespace' >> ~/.bashrc && \
    echo 'if [ ! -f ~/.post-create-complete ] && [ -f /usr/local/share/post-create.sh ]; then' >> ~/.bashrc && \
    echo '    /usr/local/share/post-create.sh' >> ~/.bashrc && \
    echo '    touch ~/.post-create-complete' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc

# Layer 3: Copy dependency files BEFORE install (cache key)
# These files determine when deps layer needs to rebuild
COPY --chown=user:user pyproject.toml pdm.lock ./

# Layer 4: Configure PDM and install dependencies
# Only rebuilds when pyproject.toml or pdm.lock changes
RUN mkdir -p /opt/chipflow-cache/pdm /opt/chipflow-cache/yowasp /opt/chipflow-cache/zig /opt/chipflow-cache/uv && \
    pdm config use_uv true && \
    pdm config cache_dir /opt/chipflow-cache/pdm && \
    echo "Python version: $(python --version)" && \
    echo "PDM install starting..." && \
    pdm -vv -n install && \
    pdm config check_update false

# Layer 5: Copy cache-warming design and warm caches
# Only rebuilds when deps change
COPY --chown=user:user cache-warming /home/user/cache-warming-temp

RUN export YOWASP_CACHE_DIR=/opt/chipflow-cache/yowasp && \
    export ZIG_GLOBAL_CACHE_DIR=/opt/chipflow-cache/zig && \
    echo "Warming yowasp-yosys cache" && \
    pdm run yowasp-yosys --version && \
    echo "Warming zig cache" && \
    cd cache-warming-temp && \
    pdm run chipflow pin lock && \
    pdm run chipflow sim build && \
    cd .. && \
    rm -rf cache-warming-temp && \
    echo "Copying uv cache to /opt/chipflow-cache" && \
    cp -r ~/.cache/uv/* /opt/chipflow-cache/uv/
