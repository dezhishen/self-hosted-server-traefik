#!/bin/sh
# ── opencode 运行时初始化 ──

# ── APK_ROOT 默认值（兼容旧镜像无 ENV 的情况）──
APK_ROOT="${APK_ROOT:-/apk-root}"

# ── 确保 APK 基础目录结构存在 ──
mkdir -p "$APK_ROOT/etc/apk/keys" "$APK_ROOT/lib/apk" "$APK_ROOT/var/cache/apk" "$APK_ROOT/etc/apk/protected_paths.d"

# ── 同步最新 APK 签名密钥（从运行时基础镜像获取，避免构建时密钥过期）──
cp -a /etc/apk/keys/* "$APK_ROOT/etc/apk/keys/" 2>/dev/null

# ── 强制重建 apk 数据库（设置环境变量 OPENCODE_APK_FORCE_INIT=true）──
if [ "$OPENCODE_APK_FORCE_INIT" = "true" ]; then
    echo "[opencode] 强制重建 apk 数据库..."
    cp "$APK_ROOT/etc/apk/world" /tmp/apk-world.bak 2>/dev/null
    rm -rf "$APK_ROOT/lib/apk" "$APK_ROOT/etc/apk"/scripts.d "$APK_ROOT/var/cache/apk" 2>/dev/null
    mkdir -p "$APK_ROOT/lib/apk" "$APK_ROOT/var/cache/apk"
fi

# ── 首次/强制初始化 apk root ──
if [ ! -f "$APK_ROOT/lib/apk/db/installed" ]; then
    echo "[opencode] 初始化 apk 数据库..."
    mkdir -p "$APK_ROOT/etc/apk"
    cp /usr/local/share/opencode-apk/repositories "$APK_ROOT/etc/apk/"
    # 切镜像源（在首次 update 之前，避免先走默认源再切）
    if [ "$OPENCODE_APK_MIRROR" = "aliyun" ]; then
        echo "[opencode] 使用阿里云 APK 镜像源..."
        sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' "$APK_ROOT/etc/apk/repositories"
    fi
    /sbin/apk.real --root "$APK_ROOT" --usermode add --initdb --no-cache
    /sbin/apk.real --root "$APK_ROOT" update --no-cache
    if [ -f /tmp/apk-world.bak ]; then
        cp /tmp/apk-world.bak "$APK_ROOT/etc/apk/world"
    fi
fi

# ── 恢复已安装的包 ──
if [ -f "$APK_ROOT/etc/apk/world" ] && [ -s "$APK_ROOT/etc/apk/world" ]; then
    echo "[opencode] 恢复已安装的 apk 包..."
    /sbin/apk.real --root "$APK_ROOT" --usermode add --no-cache $(cat "$APK_ROOT/etc/apk/world")
fi

# ── 软链接 apk-root 可执行文件 → ~/.local/bin ──
mkdir -p /home/opencode/.local/bin
for d in "$APK_ROOT/usr/bin" "$APK_ROOT/usr/sbin" "$APK_ROOT/bin" "$APK_ROOT/sbin"; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
        [ -f "$f" ] && ln -sf "$f" /home/opencode/.local/bin/ 2>/dev/null
    done
done
echo "[opencode] 环境就绪"
exec opencode "$@"
