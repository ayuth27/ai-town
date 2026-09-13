# Use an Ubuntu base image
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    python3 \
    python3-pip \
    unzip \
    socat \
    build-essential \
    libssl-dev \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Install NVM into a shared prefix so a non-root user can read it too
ENV NVM_DIR=/opt/nvm
ENV NODE_VERSION=18.0.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install NVM, Node.js, and npm
# hadolint ignore=SC1091
RUN mkdir -p "$NVM_DIR" && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash && \
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \
    nvm install 18 && \
    nvm use 18

# Add NVM to PATH
# hadolint ignore=SC1091
RUN . "$NVM_DIR/nvm.sh" && nvm install "$NODE_VERSION"
ENV NODE_PATH=$NVM_DIR/versions/node/v$NODE_VERSION/lib/node_modules
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Create an unprivileged user to run the app. uid/gid 1000 matches the usual
# host user, so the bind mount used by docker-compose stays writable.
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash appuser

# Set the working directory
WORKDIR /usr/src/app

# Copy dependency files
COPY package*.json ./

# Install npm dependencies
RUN npm install && npx update-browserslist-db@latest

# Copy application files
COPY . .

# Hand the app directory (node_modules included, since docker-compose seeds an
# anonymous volume from it) to the unprivileged user
RUN chown -R appuser:appuser /usr/src/app

# Expose necessary ports
EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:5173/ || exit 1

USER appuser

CMD ["npx", "vite", "--host"]
