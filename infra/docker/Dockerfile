# Base image
FROM ubuntu:22.04

# Build arguments
ARG FLUTTER_VERSION=stable
ARG AWS_CLI_VERSION=2.15.0

# Set non-interactive mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables
ENV PATH="/flutter/bin:${PATH}" \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8

# Install prerequisite packages and set up tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        locales \
        ca-certificates \
        groff \
        less \
        openssh-client \
        python3 \
        python3-pip && \
    # Set up locale
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Clone the Flutter repository with specified version
RUN git clone -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /flutter && \
    flutter precache && \
    flutter doctor && \
    flutter config --enable-web

# Create app directory
WORKDIR /app

# Copy the build script into the container
COPY infra/docker/build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh

# # Expose port for testing (optional)
# EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD flutter doctor || exit 1

# Set entrypoint
ENTRYPOINT ["/bin/bash"]
CMD ["tail", "-f", "/dev/null"]