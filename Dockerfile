# --- 第一阶段：下载与准备 ---
# 默认版本（构建时会被 GitHub Actions 的 --build-arg 覆盖）
ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION} AS preparer

# 默认版本（构建时会被 GitHub Actions 的 --build-arg 覆盖）
ARG S6_OVERLAY_VERSION=3.2.2.0
# 自动适配架构 (x86_64 -> x86_64, arm64 -> aarch64)
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

# --- 第二阶段：最终镜像 ---
FROM alpine:${ALPINE_VERSION}

# 从 preparer 阶段只把解压好的二进制文件“偷”过来
COPY --from=preparer /s6-install/ /

# 此时你的镜像里没有 curl，没有 xz，没有 tar 包，只有 s6 本身
# 且只增加了一层极为干净的 COPY 层
ENTRYPOINT ["/init"]