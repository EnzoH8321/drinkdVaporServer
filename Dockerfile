# ================================
# Build image
# ================================
FROM swift:6.1-noble AS build

# Install OS updates and build dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
        ca-certificates \
        tzdata \
        curl \
        git \
        build-essential \
        pkg-config \
        libssl-dev \
        zlib1g-dev \
        libsqlite3-dev \
        libcurl4-openssl-dev \
        libjemalloc-dev \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# Copy Package files for dependency resolution
COPY Package.swift Package.resolved* ./

# Resolve dependencies
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build the drinkdVaporServer executable with optimizations
RUN swift build -c release --static-swift-stdlib --product drinkdVaporServer

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/drinkdVaporServer" ./

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM to staging area (if any)
RUN BIN_PATH=$(swift build --package-path /build -c release --show-bin-path) && \
    find -L "$BIN_PATH/" -name "*.resources" -exec cp -Ra {} ./ \; || true

# Copy any resources from the public directory and views directory if the directories exist
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Install runtime dependencies and websocat
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
        ca-certificates \
        tzdata \
        curl \
        libssl3 \
        zlib1g \
        libsqlite3-0 \
        libcurl4 \
        libjemalloc2 \
        wget \
        openssl \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates \
    && wget -O /usr/local/bin/websocat https://github.com/vi/websocat/releases/download/v1.12.0/websocat.x86_64-unknown-linux-musl \
    && chmod +x /usr/local/bin/websocat

# Set SSL environment variables for proper certificate validation
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_DIR=/etc/ssl/certs

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

# Environment variables for production
ENV LOG_LEVEL=info
ENV ENVIRONMENT=production

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the drinkdVaporServer when the image is run
ENTRYPOINT ["./drinkdVaporServer"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]