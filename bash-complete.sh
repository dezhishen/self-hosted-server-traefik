#!/bin/bash
# bash-complete.sh
# 用法:
#   ./bash-complete.sh install    安装 bash 自动补全
#   ./bash-complete.sh uninstall  卸载 bash 自动补全

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLETION_FILE="/etc/bash_completion.d/self-hosted-server-traefik"
MARKER="# self-hosted-server-traefik-completion"

_gen_completion_content() {
    # 动态从 scripts/install-*.sh 提取应用名称列表
    local apps
    apps=$(ls "${SCRIPT_DIR}/scripts/install-"*.sh 2>/dev/null \
        | sed 's|.*/install-||;s|\.sh$||' \
        | sort \
        | tr '\n' ' ')

    cat <<EOF
${MARKER}
_install_one_completions() {
    local cur="\${COMP_WORDS[COMP_CWORD]}"
    local apps="${apps}"
    COMPREPLY=( \$(compgen -W "\${apps}" -- "\${cur}") )
}
complete -F _install_one_completions install-one.sh
complete -F _install_one_completions ./install-one.sh

_stop_container_completions() {
    local cur="\${COMP_WORDS[COMP_CWORD]}"
    local containers
    containers=\$(podman ps --format '{{.Names}}' 2>/dev/null | tr '\n' ' ')
    COMPREPLY=( \$(compgen -W "\${containers}" -- "\${cur}") )
}
complete -F _stop_container_completions stop-container.sh
complete -F _stop_container_completions ./scripts/stop-container.sh
${MARKER}-end
EOF
}

do_install() {
    if [ -d /etc/bash_completion.d ]; then
        echo "安装补全脚本到 ${COMPLETION_FILE} ..."
        _gen_completion_content | sudo tee "${COMPLETION_FILE}" > /dev/null
        echo "安装完成，请执行以下命令立即生效:"
        echo "  source ${COMPLETION_FILE}"
    else
        # 写入用户 .bashrc
        local bashrc="${HOME}/.bashrc"
        if grep -q "${MARKER}" "${bashrc}" 2>/dev/null; then
            echo "补全脚本已存在于 ${bashrc}，跳过"
            return 0
        fi
        echo "安装补全脚本到 ${bashrc} ..."
        echo "" >> "${bashrc}"
        _gen_completion_content >> "${bashrc}"
        echo "安装完成，请执行以下命令立即生效:"
        echo "  source ${bashrc}"
    fi
}

do_uninstall() {
    if [ -f "${COMPLETION_FILE}" ]; then
        echo "卸载补全脚本 ${COMPLETION_FILE} ..."
        sudo rm -f "${COMPLETION_FILE}"
        echo "卸载完成"
    fi

    local bashrc="${HOME}/.bashrc"
    if grep -q "${MARKER}" "${bashrc}" 2>/dev/null; then
        echo "从 ${bashrc} 移除补全脚本 ..."
        # 删除从 MARKER 到 MARKER-end 之间的内容（含空行）
        sed -i "/^${MARKER}$/,/^${MARKER}-end$/d" "${bashrc}"
        # 删除可能遗留的空行
        sed -i '/^$/N;/^\n$/d' "${bashrc}"
        echo "卸载完成"
    fi
}

case "$1" in
    install)
        do_install
        ;;
    uninstall)
        do_uninstall
        ;;
    *)
        echo "用法: $0 {install|uninstall}"
        exit 1
        ;;
esac
