#!/bin/bash
set -e
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=opencode
port=4096


# ---------- 获取访问密码 ----------
OPENCODE_PASSWORD=$(`dirname $0`/get-args.sh OPENCODE_PASSWORD "OpenCode 访问密码")
if [ -z "$OPENCODE_PASSWORD" ]; then
    read -p "请输入OpenCode访问密码:" OPENCODE_PASSWORD
    if [ -z "$OPENCODE_PASSWORD" ]; then
        echo "随机生成密码"
        OPENCODE_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
        echo "生成的密码为: $OPENCODE_PASSWORD"
    fi
    `dirname $0`/set-args.sh OPENCODE_PASSWORD "$OPENCODE_PASSWORD"
fi

# ---------- SSH 配置 ----------
OPENCODE_SSH_MODE=$(`dirname $0`/get-args.sh OPENCODE_SSH_MODE "SSH模式[host/independent]")
if [ -z "$OPENCODE_SSH_MODE" ] || { [ "$OPENCODE_SSH_MODE" != "host" ] && [ "$OPENCODE_SSH_MODE" != "independent" ]; }; then
    read -p "SSH 配置模式 [1:复用宿主机 ~/.ssh  2:独立SSH目录] (默认: 1):" ssh_choice
    if [ "$ssh_choice" = "2" ]; then
        OPENCODE_SSH_MODE="independent"
    else
        OPENCODE_SSH_MODE="host"
    fi
    `dirname $0`/set-args.sh OPENCODE_SSH_MODE "$OPENCODE_SSH_MODE"
fi

mkdir -p ${base_data_dir}/${container_name}/home
mkdir -p ${base_data_dir}/${container_name}/config
mkdir -p ${base_data_dir}/${container_name}/workspace
mkdir -p ${base_data_dir}/${container_name}/apt-cache

# ---------- 根据 SSH 模式准备挂载 ----------
if [ "$OPENCODE_SSH_MODE" = "independent" ]; then
    SSH_MOUNT_DIR="${base_data_dir}/${container_name}/ssh"
    mkdir -p ${SSH_MOUNT_DIR}
    chmod 700 ${SSH_MOUNT_DIR}
    SSH_VOLUME="-v ${SSH_MOUNT_DIR}:/home/opencode/.ssh"
    echo "SSH 模式: 独立 — 目录 ${SSH_MOUNT_DIR}"
    # 独立模式下自动生成 SSH 密钥对
    if [ ! -f ${SSH_MOUNT_DIR}/id_ed25519 ]; then
        echo "生成 ed25519 密钥对..."
        ssh-keygen -t ed25519 -f ${SSH_MOUNT_DIR}/id_ed25519 -N "" -C "opencode" 2>/dev/null
        echo "公钥 (添加到 GitHub/GitLab 等):"
        cat ${SSH_MOUNT_DIR}/id_ed25519.pub
    fi
else
    SSH_VOLUME="-v ${HOME}/.ssh:/home/opencode/.ssh"
    echo "SSH 模式: 复用宿主机 — ${HOME}/.ssh"
fi

# ═══════════════════════════════════════════════════════════════
# 额外文件夹映射 — POSIX sh 兼容函数
# ═══════════════════════════════════════════════════════════════
MOUNT_TMPFILE="/tmp/opencode-extra-mounts-$$"

# 添加一条映射
add_mount() {
    echo "$1" >> "$MOUNT_TMPFILE"
}

# 按行号删除一条映射
del_mount() {
    _line="$1"
    sed "${_line}d" "$MOUNT_TMPFILE" > "${MOUNT_TMPFILE}.tmp"
    mv "${MOUNT_TMPFILE}.tmp" "$MOUNT_TMPFILE"
}

# 显示当前映射列表，返回行数
list_mounts() {
    if [ -s "$MOUNT_TMPFILE" ]; then
        _count=0
        while IFS= read -r _entry; do
            _count=$((_count + 1))
            echo "  [${_count}] ${_entry}"
        done < "$MOUNT_TMPFILE"
        return $_count
    fi
    return 0
}

# 将临时文件内容保存到 set-args，清理临时文件
save_mounts() {
    if [ -s "$MOUNT_TMPFILE" ]; then
        _saved=""
        while IFS= read -r _entry; do
            if [ -z "$_saved" ]; then
                _saved="$_entry"
            else
                _saved="${_saved}|${_entry}"
            fi
        done < "$MOUNT_TMPFILE"
        `dirname $0`/set-args.sh OPENCODE_EXTRA_MOUNTS "$_saved"
    fi
    rm -f "$MOUNT_TMPFILE"
}

# 将 | 分隔的字符串转换为 docker -v 参数
mounts_to_docker_volumes() {
    _volumes=""
    _input="$1"
    if [ -n "$_input" ]; then
        _saved_IFS="$IFS"
        IFS='|'
        for _entry in $_input; do
            _volumes="$_volumes -v $_entry"
        done
        IFS="$_saved_IFS"
    fi
    echo "$_volumes"
}

# 将 | 分隔的字符串转为可读格式
mounts_to_display() {
    _input="$1"
    if [ -n "$_input" ]; then
        echo "$_input" | tr '|' ', '
    fi
}
# ═══════════════════════════════════════════════════════════════

# ---------- 额外文件夹映射 ----------
EXTRA_VOLUMES=""
OPENCODE_EXTRA_MOUNTS=$(`dirname $0`/get-args.sh OPENCODE_EXTRA_MOUNTS "额外挂载的文件夹列表")
if [ -z "$OPENCODE_EXTRA_MOUNTS" ]; then
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  额外文件夹映射 (可选)"
    echo "  格式: 宿主机路径:容器内路径"
    echo "  例如: /mnt/data:/data 或 /home/user/projects:/projects"
    echo "═══════════════════════════════════════════"

    # 初始化临时文件
    > "$MOUNT_TMPFILE"

    while true; do
        echo ""
        if [ -s "$MOUNT_TMPFILE" ]; then
            echo "当前已添加的映射:"
            list_mounts
        fi
        echo ""
        echo "操作选项:"
        echo "  a) 添加映射"
        if [ -s "$MOUNT_TMPFILE" ]; then
            echo "  d) 删除映射"
            echo "  q) 完成，继续下一步"
            read -p "请选择 [a/d/q]: " mount_action
        else
            echo "  q) 完成，继续下一步"
            read -p "请选择 [a/q]: " mount_action
        fi

        case "$mount_action" in
            a|A)
                read -p "请输入映射 (宿主机路径:容器内路径): " mount_entry
                if [ -z "$mount_entry" ]; then
                    echo "输入为空，跳过"
                    continue
                fi
                # 验证格式（必须包含冒号）
                case "$mount_entry" in
                    *:*)
                        ;;
                    *)
                        echo "❌ 格式错误，需要 宿主机路径:容器内路径"
                        continue
                        ;;
                esac
                host_path="${mount_entry%%:*}"
                container_path="${mount_entry#*:}"
                # 检查宿主机路径
                if [ ! -d "$host_path" ]; then
                    read -p "宿主机目录 '$host_path' 不存在，是否自动创建？[Y/n]:" create_choice
                    if [ "$create_choice" != "n" ] && [ "$create_choice" != "N" ]; then
                        mkdir -p "$host_path" && echo "✅ 已创建: $host_path" || { echo "❌ 创建失败"; continue; }
                    else
                        echo "跳过"
                        continue
                    fi
                fi
                # 检查容器路径是否重复
                _dup=false
                if [ -s "$MOUNT_TMPFILE" ]; then
                    while IFS= read -r _existing; do
                        _existing_container="${_existing#*:}"
                        if [ "$_existing_container" = "$container_path" ]; then
                            echo "❌ 容器内路径 '$container_path' 已被映射，请勿重复"
                            _dup=true
                            break
                        fi
                    done < "$MOUNT_TMPFILE"
                fi
                if $_dup; then continue; fi
                add_mount "$mount_entry"
                echo "✅ 已添加: $mount_entry"
                ;;
            d|D)
                if [ ! -s "$MOUNT_TMPFILE" ]; then
                    echo "没有可删除的映射"
                    continue
                fi
                _total=$(wc -l < "$MOUNT_TMPFILE")
                read -p "请输入要删除的编号 [1-${_total}]: " del_idx
                case "$del_idx" in
                    ''|*[!0-9]*) echo "❌ 无效的编号"; continue ;;
                esac
                if [ "$del_idx" -ge 1 ] && [ "$del_idx" -le "$_total" ]; then
                    _removed=$(sed -n "${del_idx}p" "$MOUNT_TMPFILE")
                    del_mount "$del_idx"
                    echo "✅ 已删除: $_removed"
                else
                    echo "❌ 编号超出范围"
                fi
                ;;
            q|Q)
                break
                ;;
            *)
                echo "❌ 无效选项"
                ;;
        esac
    done

    # 保存并清理
    save_mounts
    # 重新读取保存的值
    OPENCODE_EXTRA_MOUNTS=$(`dirname $0`/get-args.sh OPENCODE_EXTRA_MOUNTS "额外挂载的文件夹列表")
fi

# 转换为 docker -v 参数
if [ -n "$OPENCODE_EXTRA_MOUNTS" ]; then
    EXTRA_VOLUMES=$(mounts_to_docker_volumes "$OPENCODE_EXTRA_MOUNTS")
    echo "额外映射: $(mounts_to_display "$OPENCODE_EXTRA_MOUNTS")"
fi

# ---------- APT 镜像源 ----------
OPENCODE_APT_MIRROR=$(`dirname $0`/get-args.sh OPENCODE_APT_MIRROR "APT镜像源[default/aliyun]")
if [ -z "$OPENCODE_APT_MIRROR" ]; then
    read -p "是否使用中国大陆 APT 镜像源（阿里云）？[y/N]:" mirror_choice
    if [ "$mirror_choice" = "y" ] || [ "$mirror_choice" = "Y" ]; then
        OPENCODE_APT_MIRROR="aliyun"
    else
        OPENCODE_APT_MIRROR="default"
    fi
    `dirname $0`/set-args.sh OPENCODE_APT_MIRROR "$OPENCODE_APT_MIRROR"
fi

# ---------- opencode 下载代理（国内加速）----------
OPENCODE_DOWNLOAD_PROXY=$(`dirname $0`/get-args.sh OPENCODE_DOWNLOAD_PROXY "opencode下载代理URL")
if [ -z "$OPENCODE_DOWNLOAD_PROXY" ]; then
    echo ""
    echo "国内用户可使用 ghproxy 加速 GitHub Release 下载"
    read -p "是否使用下载代理？[留空跳过 / 输入代理URL如 https://ghproxy.com/]:" proxy_input
    if [ -n "$proxy_input" ]; then
        # 确保以 / 结尾
        case "$proxy_input" in
            */) ;;
            *) proxy_input="${proxy_input}/" ;;
        esac
        OPENCODE_DOWNLOAD_PROXY="$proxy_input"
        echo "下载代理: $OPENCODE_DOWNLOAD_PROXY"
    else
        OPENCODE_DOWNLOAD_PROXY=""
    fi
    `dirname $0`/set-args.sh OPENCODE_DOWNLOAD_PROXY "$OPENCODE_DOWNLOAD_PROXY"
fi

# ---------- 获取镜像：优先从 ghcr.io 拉取，失败则本地构建 ----------
GHCR_IMAGE="ghcr.io/dezhishen/opencode-custom:latest"
CUSTOM_IMAGE="opencode-custom:latest"
DOCKERFILE_DIR="$(dirname $0)/../docker/opencode"

# 判断是否需要本地构建
NEED_LOCAL_BUILD=false
if [ "${OPENCODE_BUILD_LOCAL}" = "true" ]; then
    NEED_LOCAL_BUILD=true
    echo "强制本地构建模式"
elif [ "$(id -u)" != "1000" ]; then
    echo "当前 UID=$(id -u) 与镜像预设 UID=1000 不符，将本地构建"
    NEED_LOCAL_BUILD=true
fi

if ! $NEED_LOCAL_BUILD; then
    echo "从 ghcr.io 拉取预构建镜像..."
    if docker pull ${GHCR_IMAGE} 2>/dev/null; then
        docker tag ${GHCR_IMAGE} ${CUSTOM_IMAGE}
        echo "✅ 镜像拉取成功: ${GHCR_IMAGE}"
    else
        echo "⚠ 拉取失败，回退到本地构建"
        NEED_LOCAL_BUILD=true
    fi
fi

if $NEED_LOCAL_BUILD; then
    # ── 检测 opencode 版本号（latest → 转具体版本，避免缓存陈旧）──
    BUILD_VERSION="${OPENCODE_VERSION:-latest}"
    if [ "$BUILD_VERSION" = "latest" ]; then
        echo "检测最新 opencode 版本..."
        DETECTED=$(curl -sfL https://api.github.com/repos/anomalyco/opencode/releases/latest 2>/dev/null \
            | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
        if [ -n "$DETECTED" ]; then
            BUILD_VERSION="$DETECTED"
            echo "最新版本: $BUILD_VERSION（以此为缓存键）"
        fi
    fi

    echo "构建 opencode 自定义镜像（Ubuntu 24.04, uid=$(id -u), gid=$(id -g)）..."
    docker build \
        --build-arg UID=$(id -u) \
        --build-arg GID=$(id -g) \
        --build-arg APT_MIRROR="${OPENCODE_APT_MIRROR}" \
        --build-arg OPENCODE_DOWNLOAD_PROXY="${OPENCODE_DOWNLOAD_PROXY}" \
        --build-arg OPENCODE_VERSION="${BUILD_VERSION}" \
        -t ${CUSTOM_IMAGE} \
        ${DOCKERFILE_DIR}
fi

# ---------- 网络模式选择 ----------
usemacvlan=$(`dirname $0`/get-args.sh usemacvlan "是否使用macvlan[y/n]")
if [ -z "$usemacvlan" ]; then
    read -p "是否使用macvlan[y/n]:" usemacvlan
    `dirname $0`/set-args.sh usemacvlan "$usemacvlan"
fi

case $usemacvlan in
    y)
        docker_macvlan_network_name=$(`dirname $0`/get-args.sh docker_macvlan_network_name "macvlan的网络名")
        `dirname $0`/set-docker-macvlan-ip.sh ${container_name}
        the_ip=$(`dirname $0`/get-docker-macvlan-ip.sh ${container_name})
        echo "macvlan 模式: IP=${the_ip}"
        MACVLAN_NET="--network=${docker_macvlan_network_name} --ip=${the_ip} --hostname=${container_name}"
    ;;
    *)
        BRIDGE_NET="--network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name}"
    ;;
esac

# ---------- GPU 透传 ----------
GPU_DEVICE=""
GPU_GROUP_ADD=""
if [ -e /dev/dri ]; then
    video_gid=$(getent group video | cut -d ":" -f 3)
    render_gid=$(getent group render | cut -d ":" -f 3)
    if [ -n "$video_gid" ] && [ -n "$render_gid" ]; then
        echo "检测到 /dev/dri，启用 GPU 透传"
        GPU_DEVICE="--device /dev/dri:/dev/dri"
        GPU_GROUP_ADD="--group-add ${video_gid} --group-add ${render_gid}"
    fi
fi

`dirname $0`/stop-container.sh ${container_name} || true

docker run -d --name=${container_name} \
    --restart=always \
    --user $(id -u):$(id -g) \
    -m 2G \
    --shm-size=1g \
    ${GPU_DEVICE} \
    ${GPU_GROUP_ADD} \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    -e HOME=/home/opencode \
    -e XDG_CONFIG_HOME=/home/opencode/.config \
    -e XDG_DATA_HOME=/home/opencode/.local/share \
    -e XDG_CACHE_HOME=/home/opencode/.cache \
    -e BUN_INSTALL=/home/opencode/.bun \
    -e OPENCODE_SERVER_PASSWORD=${OPENCODE_PASSWORD} \
    -e OPENCODE_PORT=${port} \
    -e OPENCODE_APT_MIRROR=${OPENCODE_APT_MIRROR} \
    -v ${base_data_dir}/${container_name}/home:/home/opencode \
    ${SSH_VOLUME} \
    ${EXTRA_VOLUMES} \
    -e OPENCODE_SSH_MODE=${OPENCODE_SSH_MODE} \
    -v ${base_data_dir}/${container_name}/config:/home/opencode/.config/opencode \
    -v ${base_data_dir}/${container_name}/workspace:/workspace \
    -v ${base_data_dir}/${container_name}/apt-cache:/var/cache/apt \
    -w /workspace \
    ${MACVLAN_NET} \
    ${BRIDGE_NET} \
    --label "traefik.enable=true" \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${CUSTOM_IMAGE} serve --port ${port} --hostname 0.0.0.0

# macvlan 模式: 生成 Traefik provider 配置文件
case $usemacvlan in
    y)
        `dirname $0`/create-traefik-provider-macvlan.sh $domain $base_data_dir $docker_macvlan_network_name $tls $container_name $port
    ;;
esac

# ═══════════════════════════════════════════════════════════════
# 启动后汇总信息 & 使用帮助
# ═══════════════════════════════════════════════════════════════
sleep 2
if docker ps --format '{{.Names}}' | grep -qx "${container_name}"; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           OpenCode 容器启动成功                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  访问地址:  https://${container_name}.${domain}              "
    echo "║  访问密码:  ${OPENCODE_PASSWORD}                            "
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  持久化卷:                                                  ║"
    echo "║    用户数据:  ${base_data_dir}/${container_name}/home       "
    echo "║    工作目录:  ${base_data_dir}/${container_name}/workspace  "
    echo "║    APT 缓存:  ${base_data_dir}/${container_name}/apt-cache  "
    if [ "$OPENCODE_SSH_MODE" = "independent" ]; then
    echo "║    SSH 密钥:  ${SSH_MOUNT_DIR}                              "
    else
    echo "║    SSH 密钥:  复用宿主机 ~/.ssh                             "
    fi
    if [ -n "$OPENCODE_EXTRA_MOUNTS" ]; then
        _saved_IFS="$IFS"
        IFS='|'
        for _mnt in $OPENCODE_EXTRA_MOUNTS; do
            [ -n "$_mnt" ] && echo "║    额外映射:  $_mnt"
        done
        IFS="$_saved_IFS"
    fi
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  常用命令:                                                  ║"
    echo "║    docker exec -it ${container_name} bash                   "
    echo "║    docker logs -f ${container_name}                        "
    echo "║    docker restart ${container_name}                        "
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  容器内操作:                                                ║"
    echo "║    apt install <包名>   → 安装并自动持久化                  "
    echo "║    sudo apt update      → 更新源                            "
    echo "║    exit                 → 退出容器                          "
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
else
    echo "⚠️ 容器可能未正常启动，请检查日志:"
    echo "   docker logs ${container_name}"
fi
