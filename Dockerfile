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