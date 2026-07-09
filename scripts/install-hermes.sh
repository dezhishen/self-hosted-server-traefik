#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=hermes
image=nousresearch/hermes-agent:latest
port=9119

# ---------- 获取 Dashboard 认证用户名 ----------
HERMES_USERNAME=$(`dirname $0`/get-args.sh HERMES_USERNAME "Hermes Dashboard 用户名")
if [ -z "$HERMES_USERNAME" ]; then
    read -p "请输入Hermes Dashboard用户名:" HERMES_USERNAME
    if [ -z "$HERMES_USERNAME" ]; then
        echo "用户名使用默认值: admin"
        HERMES_USERNAME="admin"
    fi
    `dirname $0`/set-args.sh HERMES_USERNAME "$HERMES_USERNAME"
fi

# ---------- 获取 Dashboard 认证密码 ----------
HERMES_PASSWORD=$(`dirname $0`/get-args.sh HERMES_PASSWORD "Hermes Dashboard 密码")
if [ -z "$HERMES_PASSWORD" ]; then
    read -p "请输入Hermes Dashboard密码:" HERMES_PASSWORD
    if [ -z "$HERMES_PASSWORD" ]; then
        echo "随机生成密码"
        HERMES_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
        echo "生成的密码为: $HERMES_PASSWORD"
    fi
    `dirname $0`/set-args.sh HERMES_PASSWORD "$HERMES_PASSWORD"
fi

# ---------- 获取 Dashboard 会话密钥（用于重启后保持会话）----------
HERMES_SECRET=$(`dirname $0`/get-args.sh HERMES_SECRET "Hermes Dashboard 会话密钥")
if [ -z "$HERMES_SECRET" ]; then
    echo "自动生成会话密钥（用于容器重启后保持登录状态）"
    HERMES_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    `dirname $0`/set-args.sh HERMES_SECRET "$HERMES_SECRET"
fi

mkdir -p ${base_data_dir}/${container_name}/data

video_gid=$(getent group video | cut -d ":" -f 3)
render_gid=$(getent group render | cut -d ":" -f 3)
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
    -d --restart=always \
    -e HERMES_DASHBOARD=1 \
    -e HERMES_DASHBOARD_HOST=0.0.0.0 \
    -e HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${HERMES_USERNAME} \
    -e HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${HERMES_PASSWORD} \
    -e HERMES_DASHBOARD_BASIC_AUTH_SECRET=${HERMES_SECRET} \
    -m 2G \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    -v ${base_data_dir}/${container_name}/data:/opt/data \
    --shm-size=1g \
    --device /dev/dri:/dev/dri \
    --group-add ${video_gid} \
    --group-add ${render_gid} \
    --network=${docker_network_name} --network-alias=${container_name} \
    --hostname=${container_name} \
    --label "traefik.enable=true" \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image} gateway run
