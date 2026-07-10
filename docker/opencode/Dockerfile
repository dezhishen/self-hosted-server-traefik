# ─────────────────────────────────────────────────────────────
# opencode Ubuntu 镜像 — apt 持久化 (多阶段构建)
#   Stage 1: download — 下载 & 解压 opencode 二进制
#   Stage 2: final   — Ubuntu 24.04 运行环境
# ─────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════
# Stage 1: 下载 opencode 二进制（独立阶段，隔离网络/解压问题）
# ═══════════════════════════════════════════════════════════════
FROM alpine:3.20 AS download

# OPENCODE_VERSION: 具体版本号时直接下载；latest 时用 /latest/download/ 重定向
ARG OPENCODE_VERSION=latest
ARG OPENCODE_DOWNLOAD_PROXY=""
ARG APT_MIRROR=""

# ── Step 1: 安装下载工具（失败则换源或网络问题）──
RUN if [ "${APT_MIRROR}" = "aliyun" ]; then \
        echo "[download] 切换 Alpine 镜像源至阿里云..."; \
        sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories; \
    fi \
    && apk add --no-cache curl tar grep sed

# ── Step 2: 下载 & 解压 opencode ──
RUN set -ex \
    && ARCH=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/') \
    && VERSION="${OPENCODE_VERSION}" \
    && PROXY="${OPENCODE_DOWNLOAD_PROXY}" \
    && RELEASES_URL="https://github.com/anomalyco/opencode/releases" \
    && mkdir -p /out \
    \
    && if [ "$VERSION" != "latest" ]; then \
        BASE_URL="${RELEASES_URL}/download/${VERSION}/opencode-linux-${ARCH}"; \
    else \
        BASE_URL="${RELEASES_URL}/latest/download/opencode-linux-${ARCH}"; \
    fi \
    && [ -n "$PROXY" ] && BASE_URL="${PROXY}${BASE_URL}" \
    && echo "[download] 下载 opencode (${VERSION}, linux-${ARCH})..." \
    \
    && if curl -fsSL "${BASE_URL}.tar.gz" -o /tmp/opencode.tar.gz 2>/dev/null; then \
        echo "[download] 解压 tar.gz..."; \
        tar -xzf /tmp/opencode.tar.gz -C /out/; \
        rm -f /tmp/opencode.tar.gz; \
    fi \
    \
    && if [ ! -f /out/opencode ]; then \
        echo "[download] 尝试裸二进制..."; \
        curl -fsSL "${BASE_URL}" -o /out/opencode 2>/dev/null || true; \
    fi

# ── Step 3: 最终验证 ──
RUN if [ ! -f /out/opencode ]; then \
        echo "[download] ❌ opencode 下载失败！"; \
        echo "[download] 请检查网络或设置 OPENCODE_DOWNLOAD_PROXY"; \
        exit 1; \
    fi \
    && chmod +x /out/opencode \
    && echo "[download] opencode 就绪: $(file /out/opencode)"

# ═══════════════════════════════════════════════════════════════
# Stage 2: Ubuntu 24.04 运行环境
# ═══════════════════════════════════════════════════════════════
FROM ubuntu:24.04

# ── 构建参数 ──
ARG UID=1000
ARG GID=1000
ARG APT_MIRROR=""

# ── 从 download 阶段复制 opencode 二进制 ──
COPY --from=download /out/opencode /usr/local/bin/opencode

# ═══════════════════════════════════════════════════════════════
# [3] 静态环境变量（很少变动）
# ═══════════════════════════════════════════════════════════════
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    HOME=/home/opencode \
    PATH="/home/opencode/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    XDG_CONFIG_HOME=/home/opencode/.config \
    XDG_DATA_HOME=/home/opencode/.local/share \
    XDG_CACHE_HOME=/home/opencode/.cache

# ═══════════════════════════════════════════════════════════════
# [3a] 构建时 APT 镜像源切换（中国大陆用户加速构建）
#      仅在 APT_MIRROR=aliyun 时生效
# ═══════════════════════════════════════════════════════════════
RUN if [ "${APT_MIRROR}" = "aliyun" ]; then \
        echo "[build] 切换 APT 镜像源至阿里云..."; \
        sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
        sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list 2>/dev/null || \
        sed -i 's|http://ports.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
        sed -i 's|http://ports.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list 2>/dev/null || true; \
    fi

# ═══════════════════════════════════════════════════════════════
# [4] 基础系统依赖 + snap/遥测清理（很少变动）
# ═══════════════════════════════════════════════════════════════
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg \
        git git-lfs \
        build-essential pkg-config \
        python3 python3-pip python3-venv \
        nodejs npm \
        ripgrep fd-find fzf jq \
        unzip zip xz-utils \
        openssh-client \
        locales tzdata \
        sudo bash-completion \
    \
    # ── 彻底移除 snapd ──
    && apt-get purge -y snapd 2>/dev/null || true \
    && rm -rf /var/cache/snapd /snap /var/snap \
    \
    # ── 移除 Ubuntu 遥测/广告/无用服务 ──
    && apt-get purge -y \
        ubuntu-advantage-tools ubuntu-pro-client \
        motd-news-config update-notifier-common \
        popularity-contest landscape-common \
        apport apport-symptoms whoopsie \
        2>/dev/null || true \
    && rm -f /etc/apt/apt.conf.d/20apt-esm-hook.conf \
    && rm -f /etc/update-motd.d/*-news \
    \
    # ── 禁用 apt 定时任务 & motd 广告 ──
    && systemctl disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true \
    && systemctl mask apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true \
    && sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news 2>/dev/null || true \
    && rm -f /etc/update-motd.d/50-motd-news \
    \
    # ── 清理 ──
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ═══════════════════════════════════════════════════════════════
# [5]+[6] locale 生成 + 环境变量（很少变动）
# ═══════════════════════════════════════════════════════════════
RUN locale-gen zh_CN.UTF-8 en_US.UTF-8
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:en

# ═══════════════════════════════════════════════════════════════
# [7] 全局 shell profile（很少变动）
# ═══════════════════════════════════════════════════════════════
RUN echo 'export PATH="/home/opencode/.local/bin:${PATH}"' > /etc/profile.d/opencode.sh \
    && echo 'export LANG=zh_CN.UTF-8'  >> /etc/profile.d/opencode.sh \
    && echo 'export LC_ALL=zh_CN.UTF-8' >> /etc/profile.d/opencode.sh \
    && echo "alias ll='ls -alFh --color=auto'" >> /etc/profile.d/opencode.sh \
    && echo "alias la='ls -Ah --color=auto'"  >> /etc/profile.d/opencode.sh \
    && chmod +x /etc/profile.d/opencode.sh

# ═══════════════════════════════════════════════════════════════
# [8] 创建 opencode 用户（跟随 UID/GID 变动）
#     如目标 UID/GID 已被占用，重命名已有用户/组而非删除
# ═══════════════════════════════════════════════════════════════
RUN if getent group ${GID} > /dev/null 2>&1; then \
        OLD_GROUP=$(getent group ${GID} | cut -d: -f1); \
        if [ "$OLD_GROUP" != "open" ]; then \
            echo "[build] GID=${GID} 已被 '$OLD_GROUP' 占用，重命名为 opencode"; \
            groupmod -n opencode "$OLD_GROUP"; \
        fi; \
    else \
        groupadd -g ${GID} opencode; \
    fi \
    && if id -nu ${UID} > /dev/null 2>&1; then \
        OLD_USER=$(id -nu ${UID}); \
        if [ "$OLD_USER" != "opencode" ]; then \
            echo "[build] UID=${UID} 已被 '$OLD_USER' 占用，重命名为 opencode"; \
            usermod -l opencode -d /home/opencode -m "$OLD_USER"; \
            usermod -s /bin/bash opencode; \
            usermod -g opencode opencode; \
        fi; \
    else \
        useradd -u ${UID} -g opencode -m -d /home/opencode -s /bin/bash opencode; \
    fi \
    && echo "opencode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/opencode \
    && chmod 440 /etc/sudoers.d/opencode \
    && mkdir -p /home/opencode/.local/bin /home/opencode/.config /home/opencode/workspace \
    && chown -R opencode:opencode /home/opencode

# ═══════════════════════════════════════════════════════════════
# [9] apt 持久化 wrapper（跟随 wrapper 脚本变动）
#      拦截 apt/apt-get install，自动记录包名到持久化列表
# ═══════════════════════════════════════════════════════════════
COPY apt-get.wrapper /usr/bin/apt-get.wrapper
COPY apt.wrapper /usr/bin/apt.wrapper
COPY dpkg.wrapper /usr/bin/dpkg.wrapper
RUN mv /usr/bin/apt-get /usr/bin/apt-get.real \
    && mv /usr/bin/apt-get.wrapper /usr/bin/apt-get \
    && chmod +x /usr/bin/apt-get \
    && mv /usr/bin/apt /usr/bin/apt.real \
    && mv /usr/bin/apt.wrapper /usr/bin/apt \
    && chmod +x /usr/bin/apt \
    && mv /usr/bin/dpkg /usr/bin/dpkg.real \
    && mv /usr/bin/dpkg.wrapper /usr/bin/dpkg \
    && chmod +x /usr/bin/dpkg

# ═══════════════════════════════════════════════════════════════
# [10] 运行时入口（跟随 entrypoint.sh 变动）
# ═══════════════════════════════════════════════════════════════
COPY entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/opencode-healthcheck.sh
RUN chmod +x /usr/local/bin/opencode-entrypoint.sh \
    && chmod +x /usr/local/bin/opencode-healthcheck.sh

# ═══════════════════════════════════════════════════════════════
# [10a] 健康检查（start-period 覆盖 apt 恢复 + opencode 启动时间）
#       初始化阶段（无就绪标记）→ 始终放行，不会因启动慢被误杀
# ═══════════════════════════════════════════════════════════════
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
    CMD ["/usr/local/bin/opencode-healthcheck.sh"]

# ═══════════════════════════════════════════════════════════════
# [11] 运行态配置（不产生层）
# ═══════════════════════════════════════════════════════════════
VOLUME /home/opencode
VOLUME /var/cache/apt
USER opencode
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
