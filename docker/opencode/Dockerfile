# 自定义 opencode 镜像 — 透明 apk 持久化
# 所有 apk add 自动重定向到 /apk-root（持久化卷），容器重建不丢包
ARG BASE_IMAGE=ghcr.io/anomalyco/opencode
FROM ${BASE_IMAGE}

# ── 宿主机用户 UID/GID（构建时传入，确保容器内用户与宿主机一致）──
ARG UID=1000
ARG GID=1000

# ── 声明持久化卷 ──
VOLUME /apk-root

# ── 替换 /sbin/apk 为 wrapper，透明注入 --root ──
RUN mv /sbin/apk /sbin/apk.real \
    && echo '#!/bin/sh'        > /sbin/apk \
    && echo 'exec /sbin/apk.real --root /apk-root "$@"' >> /sbin/apk \
    && chmod +x /sbin/apk

# ── 创建 opencode 用户（UID/GID 与宿主机一致）──
RUN addgroup -g ${GID} opencode \
    && adduser -u ${UID} -G opencode -h /home/opencode -D opencode \
    && mkdir -p /home/opencode/.local/bin

# ── 预建目录 & 保存 apk 配置（运行时由 entrypoint 复制到 /apk-root）──
RUN mkdir -p /usr/local/bin /usr/local/lib /usr/local/include /usr/local/lib/pkgconfig \
    && mkdir -p /apk-root/etc/apk \
    && cp /etc/apk/repositories /apk-root/etc/apk/repositories \
    && mkdir -p /usr/local/share/opencode-apk \
    && cp -a /etc/apk/keys /usr/local/share/opencode-apk/keys \
    && cp /etc/apk/repositories /usr/local/share/opencode-apk/repositories

# ── shell profile（登录时自动扩展 PATH）──
RUN echo 'export PATH="/home/opencode/.local/bin:/apk-root/usr/bin:/apk-root/usr/sbin:/apk-root/bin:/apk-root/sbin:${PATH}"' > /etc/profile.d/opencode.sh \
    && echo 'export LD_LIBRARY_PATH="/apk-root/usr/lib:/apk-root/lib:${LD_LIBRARY_PATH}"' >> /etc/profile.d/opencode.sh \
    && echo 'export PKG_CONFIG_PATH="/apk-root/usr/lib/pkgconfig:/apk-root/usr/share/pkgconfig:${PKG_CONFIG_PATH}"' >> /etc/profile.d/opencode.sh \
    && chmod +x /etc/profile.d/opencode.sh

# ── 修正权限 ──
RUN chown -R opencode:opencode /home/opencode /apk-root

# ── 运行时初始化 & 入口 ──
COPY entrypoint.sh /usr/local/bin/opencode-entrypoint.sh
RUN chmod +x /usr/local/bin/opencode-entrypoint.sh

USER opencode
ENTRYPOINT ["/usr/local/bin/opencode-entrypoint.sh"]
