FROM mcr.microsoft.com/devcontainers/python:1-3.11-bookworm

# Install system dependencies in the image build (cached in prebuild)
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    make \
    cmake \
    pkg-config \
    libffi-dev \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libgdbm-dev \
    libnss3-dev \
    liblzma-dev \
    jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ripgrep and fd
RUN curl -sSLO https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep_13.0.0_amd64.deb && \
    curl -sSLO https://github.com/sharkdp/fd/releases/download/v8.7.0/fd_8.7.0_amd64.deb && \
    dpkg -i ripgrep_13.0.0_amd64.deb fd_8.7.0_amd64.deb && \
    rm -f *.deb

# Install PDM globally in the image
RUN curl -sSL https://pdm-project.org/install-pdm.py | python3 - && \
    echo 'export PATH="/root/.local/bin:$PATH"' >> /etc/bash.bashrc

# Switch to vscode user and install PDM for them too
USER vscode
RUN curl -sSL https://pdm-project.org/install-pdm.py | python3 - && \
    echo 'export PATH="/home/vscode/.local/bin:$PATH"' >> ~/.bashrc

USER root
