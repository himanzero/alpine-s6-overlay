# Alpine + s6-overlay Base Image

[![Build and Push Docker Image](https://github.com/himanzero/alpine-s6-overlay/actions/workflows/build-docker.yml/badge.svg)](https://github.com/himanzero/alpine-s6-overlay/actions/workflows/build-docker.yml)

A lightweight, multi-architecture base image combining the minimalism of **Alpine Linux** with the robust process management of **s6-overlay**.

## Why this image?

- **Minimalist**: Weighs only ~5-10MB (depending on architecture).
- **Process Management**: `s6-overlay` provides a clean way to manage multiple processes, handle signals, and manage initialization scripts in Docker containers.
- **Always Up-to-Date**: Automatically rebuilt daily whenever a new Alpine or s6-overlay version is detected.
- **Multi-Arch Support**: Built for `amd64` and `arm64`.

## Usage

You can use this image as a base for your own Dockerfiles:

```dockerfile
FROM himanzero/alpine-s6-overlay:latest

# Add your initialization scripts
# COPY root/ /

# Your app goes here
# RUN apk add --no-cache your-app

# Entrypoint is already set to /init
```

## Configuration Guide (s6-overlay v3)

This image uses **s6-overlay v3**. Configuration is handled by `s6-rc`.

### 1. Directory Structure
All service definitions should be placed in: `/etc/s6-overlay/s6-rc.d/`.
Each service is a directory named after the service.

### 2. Service Types
Inside your service directory (e.g., `/etc/s6-overlay/s6-rc.d/my-service/`), create a file named `type` containing either:
- `oneshot`: For initialization tasks that run once and exit.
- `longrun`: For daemon processes that should keep running.

### 3. Service Logic
- **For `oneshot`**: Create an executable file named `up`.
  ```bash
  /bin/echo "Performing initialization..."
  ```
  > [!IMPORTANT]
  > **Crucial Note**: The `up` file is parsed by `execlineb`, not a standard shell. It **must** be a one-line command.
- **For `longrun`**: Create an executable file named `run`.
  ```bash
  #!/bin/sh
  # Use exec to ensure the process replaces the shell and receives signals
  exec my-daemon --option
  ```

### 4. Resolving Dependencies
To make `service-a` depend on `service-b`:
1. Create a directory: `/etc/s6-overlay/s6-rc.d/service-a/dependencies.d/`
2. Create an empty file named `service-b` inside that directory:
   ```bash
   touch /etc/s6-overlay/s6-rc.d/service-a/dependencies.d/service-b
   ```

### 5. Enabling Your Service
By default, the overlay starts the `user` bundle. To enable your service:
1. Create the `user` bundle directory: `/etc/s6-overlay/s6-rc.d/user/`
2. Create a `type` file inside it containing the word `bundle`:
   ```bash
   echo "bundle" > /etc/s6-overlay/s6-rc.d/user/type
   ```
3. Create the `contents.d` directory: `/etc/s6-overlay/s6-rc.d/user/contents.d/`
4. Create an empty file named after your service inside that directory:
   ```bash
   touch /etc/s6-overlay/s6-rc.d/user/contents.d/my-service
   ```

### Example: Simple Nginx Service
To add Nginx as a `longrun` service:
- `/etc/s6-overlay/s6-rc.d/nginx/type` -> contains `longrun`
- `/etc/s6-overlay/s6-rc.d/nginx/run` -> contains `#!/bin/sh \n exec nginx -g "daemon off;"`
- `/etc/s6-overlay/s6-rc.d/user/type` -> contains `bundle`
- `/etc/s6-overlay/s6-rc.d/user/contents.d/nginx` -> (empty file)

---

## Tagging Strategy

- `latest`: The most recent stable build.
- `{{alpine_version}}_{{s6_overlay_version}}`: Pin to specific upstream versions (e.g., `3.23.4_3.2.2.0`).
- `{{tag}}-amd64` / `{{tag}}-arm64`: Architecture-specific tags.

## Transparency

To improve trust and transparency, here is the full `Dockerfile` used to build this image:

```dockerfile
# --- Stage 1: Download and Prepare ---
# Default version (overwritten by GitHub Actions --build-arg during build)
ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION} AS preparer

# Default version (overwritten by GitHub Actions --build-arg during build)
ARG S6_OVERLAY_VERSION=3.2.2.0
# Auto-adapt architecture (x86_64 -> x86_64, arm64 -> aarch64)
ARG TARGETARCH

RUN apk add --no-cache curl xz

WORKDIR /tmp
RUN if [ "$TARGETARCH" = "amd64" ]; then ARCH="x86_64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then ARCH="aarch64"; \
    elif [ "$TARGETARCH" = "arm" ]; then ARCH="armhf"; \
    else ARCH=$TARGETARCH; fi && \
    curl -L -O https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz && \
    curl -L -O https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.xz && \
    mkdir /s6-install && \
    tar -C /s6-install -Jxpf s6-overlay-noarch.tar.xz && \
    tar -C /s6-install -Jxpf s6-overlay-${ARCH}.tar.xz

# --- Stage 2: Final Image ---
FROM alpine:${ALPINE_VERSION}

# Copy the extracted binaries from the preparer stage
COPY --from=preparer /s6-install/ /

# Final cleanup: Remove the problematic internal user2 reference if it exists.
# This avoids 's6-rc-compile: fatal: undefined service name user2' error.
RUN rm -f /package/admin/s6-overlay-*/etc/s6-rc/sources/top/contents.d/user2 || true

# No curl, no xz, no tarballs in the final image, just s6 itself
# Only adds one clean COPY layer
ENTRYPOINT ["/init"]
```

---
Built with ❤️ and automated by GitHub Actions.
