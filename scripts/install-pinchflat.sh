#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=pinchflat
image=ghcr.io/kieraneglin/pinchflat:latest
port=8945 
mkdir -p /docker_data/${container_name}/config
PINCHFLAT_AUTH_USER=$(`dirname $0`/get-args.sh PINCHFLAT_AUTH_USER 用户名)
if [ -z "$PINCHFLAT_AUTH_USER" ]; then
    read -p "请输入用户名:" PINCHFLAT_AUTH_USER
    if [ -z "$PINCHFLAT_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        PINCHFLAT_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh PINCHFLAT_AUTH_USER "$PINCHFLAT_AUTH_USER"
fi

PINCHFLAT_AUTH_PASSWORD=$(`dirname $0`/get-args.sh PINCHFLAT_AUTH_PASSWORD 密码)
if [ -z "$PINCHFLAT_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" PINCHFLAT_AUTH_PASSWORD
    if [ -z "$PINCHFLAT_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        PINCHFLAT_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh PINCHFLAT_AUTH_PASSWORD "$PINCHFLAT_AUTH_PASSWORD"
fi
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
-m 256M \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-d --restart=always \
--user `id -u`:`id -g` \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e BASIC_AUTH_USERNAME=${PINCHFLAT_AUTH_USER} \
-e BASIC_AUTH_PASSWORD=${PINCHFLAT_AUTH_PASSWORD} \
-v /docker_data/${container_name}/config:/config \
-v /docker_data/public/youtube:/youtube \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
