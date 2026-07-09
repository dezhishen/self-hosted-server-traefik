#!/bin/sh
# ── opencode 运行时初始化 ──
APK_ROOT="/apk-root"

# ── 扩展 PATH / LD_LIBRARY_PATH ──
export PATH="/home/opencode/.local/bin:${APK_ROOT}/usr/bin:${APK_ROOT}/usr/sbin:${APK_ROOT}/bin:${APK_ROOT}/sbin:${PATH}"
export LD_LIBRARY_PATH="${APK_ROOT}/usr/lib:${APK_ROOT}/lib:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="${APK_ROOT}/usr/lib/pkgconfig:${APK_ROOT}/usr/share/pkgconfig:${PKG_CONFIG_PATH}"

# ── 首次初始化 apk root（从镜像备份复制密钥 + 建库）──
if [ ! -f "$APK_ROOT/lib/apk/db/installed" ]; then
    echo "[opencode] 首次启动，初始化 apk 数据库..."
    mkdir -p "$APK_ROOT/etc/apk"
    cp -a /usr/local/share/opencode-apk/keys "$APK_ROOT/etc/apk/"
    cp /usr/local/share/opencode-apk/repositories "$APK_ROOT/etc/apk/"
    /sbin/apk.real --root "$APK_ROOT" add --initdb --no-cache 2>/dev/null || true
    /sbin/apk.real --root "$APK_ROOT" update --no-cache 2>/dev/null || true
fi

# ── 恢复已安装的包 ──
if [ -f "$APK_ROOT/etc/apk/world" ] && [ -s "$APK_ROOT/etc/apk/world" ]; then
    echo "[opencode] 恢复已安装的 apk 包..."
    /sbin/apk.real --root "$APK_ROOT" add --no-cache $(cat "$APK_ROOT/etc/apk/world") 2>/dev/null || true
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
