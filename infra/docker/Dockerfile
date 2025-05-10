# Base image
FROM ubuntu:20.04

# Set non-interactive mode for apt-get to avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisite packages and set up AWS CLI
RUN apt-get update && \
    apt-get install -y \
        tzdata \
        keyboard-configuration \
        curl \
        unzip \
        groff \
        less \
        git && \
    # Download and install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    # Clean up
    rm -rf awscliv2.zip aws

# Clone the Flutter repository from the master branch
RUN git clone -b master https://github.com/flutter/flutter.git /flutter

# Set Flutter environment
ENV PATH="/flutter/bin:${PATH}"

# Install Flutter dependencies
RUN flutter doctor

# Set working directory
WORKDIR /tmp

# Copy the build script into the container
COPY ./docker/build.sh /tmp/build.sh

# Give execution permission to the build script
RUN chmod +x /tmp/build.sh

# Keep the container running
CMD ["tail", "-f", "/dev/null"]
