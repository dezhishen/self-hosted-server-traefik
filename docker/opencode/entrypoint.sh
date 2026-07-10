#!/bin/bash
# ── opencode Ubuntu 运行时初始化 ──
set -e

PKG_LIST="${HOME}/.config/apt-packages.list"
APT_CACHE="${APT_CACHE:-/var/cache/apt}"

# ── UID 兼容检测 ──
CURRENT_UID=$(id -u)
OPENSCODE_PASSWD_UID=$(id -u opencode 2>/dev/null || echo "0")
if [ "$CURRENT_UID" != "$OPENSCODE_PASSWD_UID" ] && [ "$OPENSCODE_PASSWD_UID" != "0" ]; then
    echo "[opencode] ⚠ 当前 UID=${CURRENT_UID} 与镜像预设 opencode UID=${OPENSCODE_PASSWD_UID} 不匹配"
    echo "[opencode] ⚠ sudo 和 apt 包管理将不可用，建议本地构建: OPENCODE_BUILD_LOCAL=true"
    APT_AVAILABLE=false
else
    APT_AVAILABLE=true
fi

# ── 确保基础目录结构 ──
mkdir -p "${HOME}/.local/bin" "${HOME}/.config" "${HOME}/workspace"

# ── 切 APT 镜像源（中国大陆用户）──
if [ "$APT_AVAILABLE" = "true" ] && [ "${OPENCODE_APT_MIRROR}" = "aliyun" ]; then
    echo "[opencode] 切换 APT 镜像源至阿里云..."
    sudo sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    sudo sed -i 's|http://archive.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list 2>/dev/null || \
    sudo sed -i 's|http://ports.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || \
    sudo sed -i 's|http://ports.ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list 2>/dev/null || true
fi

# ── 更新 APT 源 ──
if [ "$APT_AVAILABLE" = "true" ]; then
    echo "[opencode] 更新 APT 源..."
    if ! sudo apt-get.real update -qq 2>/dev/null; then
        echo "[opencode] ⚠ APT 更新失败，跳过包恢复"
    fi

    # ── 恢复持久化的 apt 包 ──
    if [ -f "${PKG_LIST}" ] && [ -s "${PKG_LIST}" ]; then
        TO_INSTALL=$(grep -v '^#' "${PKG_LIST}" | sort -u | while read -r pkg; do
            if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                echo "$pkg"
            fi
        done | tr '\n' ' ')
        
        if [ -n "${TO_INSTALL}" ]; then
            echo "[opencode] 恢复 apt 包 (${PKG_LIST}): ${TO_INSTALL}"
            sudo apt-get.real install -y --no-install-recommends ${TO_INSTALL} 2>&1 || \
                echo "[opencode] ⚠ 部分包恢复失败，继续启动..."
        else
            echo "[opencode] 所有 apt 包已就绪"
        fi
    fi
else
    echo "[opencode] ⚠ sudo 不可用，跳过 APT 包恢复"
fi

# ── 确保 ~/.local/bin 在 PATH 中 ──
case ":$PATH:" in
    *:"${HOME}/.local/bin":*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac

# ── 初始化交互 shell 体验（bashrc / profile / inputrc）──
# 仅在文件不存在时创建，已存在的用户自定义文件不会被覆盖
if [ ! -f "${HOME}/.bashrc" ]; then
    cat > "${HOME}/.bashrc" << 'BASHREOF'
# ── opencode 用户 bashrc ──
# 彩色提示符
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# 别名
alias ll='ls -alFh --color=auto'
alias la='ls -Ah --color=auto'
alias l='ls -CFh --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# 历史记录
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize

# 默认编辑器
export EDITOR=nano
export VISUAL=nano

# 语言环境
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

# 常用路径
export PATH="${HOME}/.local/bin:${PATH}"
BASHREOF
    echo "[opencode] 创建 ~/.bashrc"
fi

if [ ! -f "${HOME}/.profile" ]; then
    cat > "${HOME}/.profile" << 'PROFREOF'
# ── opencode 用户 profile ──
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
PROFREOF
    echo "[opencode] 创建 ~/.profile"
fi

if [ ! -f "${HOME}/.inputrc" ]; then
    cat > "${HOME}/.inputrc" << 'INPUTREOF'
# ── readline 配置 ──
set show-all-if-ambiguous on
set show-all-if-unmodified on
set colored-stats on
set visible-stats on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
INPUTREOF
    echo "[opencode] 创建 ~/.inputrc"
fi

echo "[opencode] 环境就绪 (Ubuntu)"

# ── 运行时诊断：确认 opencode 二进制存在 ──
if [ ! -x /usr/local/bin/opencode ]; then
    echo "[opencode] ❌ FATAL: /usr/local/bin/opencode 不存在！"
    echo "[opencode] 镜像可能构建不完整，请本地重建:"
    echo "[opencode]   OPENCODE_BUILD_LOCAL=true ./install-opencode.sh ..."
    ls -la /usr/local/bin/ 2>/dev/null
    exit 1
fi

# ── 就绪标记：通知 healthcheck 可以开始真正检测 opencode 服务 ──
touch /tmp/.opencode-ready

exec /usr/local/bin/opencode "$@"
