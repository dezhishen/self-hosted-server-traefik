#!/bin/bash
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
mkdir -p ${base_data_dir}/${container_name}/apk-root

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

# ---------- 强制重建 APK 数据库 ----------
OPENCODE_APK_FORCE_INIT="false"
if [ -d "${base_data_dir}/${container_name}/apk-root/lib/apk" ]; then
    read -p "检测到已有 APK 数据库，是否强制重建？[y/N]:" force_apk
    if [ "$force_apk" = "y" ] || [ "$force_apk" = "Y" ]; then
        OPENCODE_APK_FORCE_INIT="true"
        echo "将在启动时强制重建 APK 数据库（已安装包列表会被保留）"
    fi
fi

# ---------- APK 镜像源 ----------
OPENCODE_APK_MIRROR=$(`dirname $0`/get-args.sh OPENCODE_APK_MIRROR "APK镜像源[default/aliyun]")
if [ -z "$OPENCODE_APK_MIRROR" ]; then
    read -p "是否使用中国大陆 APK 镜像源（阿里云）？[y/N]:" mirror_choice
    if [ "$mirror_choice" = "y" ] || [ "$mirror_choice" = "Y" ]; then
        OPENCODE_APK_MIRROR="aliyun"
    else
        OPENCODE_APK_MIRROR="default"
    fi
    `dirname $0`/set-args.sh OPENCODE_APK_MIRROR "$OPENCODE_APK_MIRROR"
fi

# ---------- 构建自定义镜像（apk wrapper + entrypoint 已内置）----------
BASE_IMAGE="ghcr.io/anomalyco/opencode"
DOCKERFILE_DIR="$(dirname $0)/../docker/opencode"
CUSTOM_IMAGE="opencode-custom:latest"
docker pull ${BASE_IMAGE}
echo "构建 opencode 自定义镜像（base: ${BASE_IMAGE}, uid=$(id -u), gid=$(id -g)）..."
docker build \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    --build-arg UID=$(id -u) \
    --build-arg GID=$(id -g) \
    -t ${CUSTOM_IMAGE} \
    ${DOCKERFILE_DIR}
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

`dirname $0`/stop-container.sh ${container_name}

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
    -e OPENCODE_APK_FORCE_INIT=${OPENCODE_APK_FORCE_INIT} \
    -e OPENCODE_APK_MIRROR=${OPENCODE_APK_MIRROR} \
    -v ${base_data_dir}/${container_name}/home:/home/opencode \
    ${SSH_VOLUME} \
    -e OPENCODE_SSH_MODE=${OPENCODE_SSH_MODE} \
    -v ${base_data_dir}/${container_name}/config:/home/opencode/.config/opencode \
    -v ${base_data_dir}/${container_name}/workspace:/workspace \
    -v ${base_data_dir}/${container_name}/apk-root:/apk-root \
    -w /workspace \
    --network=${docker_network_name} --network-alias=${container_name} \
    --hostname=${container_name} \
    --label "traefik.enable=true" \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${CUSTOM_IMAGE} serve --port ${port} --hostname 0.0.0.0
