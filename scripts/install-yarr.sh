#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=yarr
image=dezhishen/yarr


YARR_AUTH_USER=$(`dirname $0`/get-args.sh YARR_AUTH_USER 用户名)
if [ -z "$YARR_AUTH_USER" ]; then
    read -p "请输入用户名:" YARR_AUTH_USER
    if [ -z "$YARR_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        YARR_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh YARR_AUTH_USER "$YARR_AUTH_USER"
fi

YARR_AUTH_PASSWORD=$(`dirname $0`/get-args.sh YARR_AUTH_PASSWORD 密码)
if [ -z "$YARR_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" YARR_AUTH_PASSWORD
    if [ -z "$YARR_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        YARR_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh YARR_AUTH_PASSWORD "$YARR_AUTH_PASSWORD"
fi


echo "用户名: $YARR_AUTH_USER"
echo "密码: $YARR_AUTH_PASSWORD"

docker pull ${image}

`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-e PUID=`id -u` -e PGID=`id -g` \
-m 128M --memory-swap 256M \
-e TZ="Asia/Shanghai" \
-e YARR_IMG_PROXY=N \
-e YARR_IMG_PROXY_EXCLUDE_DOMAINS="**.imagetwist.com,images.free4.xyz" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} \
-v ${base_data_dir}/${container_name}/data:/data \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=7070" \
--label flame.type=app \
--label flame.name=${container_name} \
--label flame.url=${container_name}.${domain} \
--label flame.icon=${container_name}.png \
${image} /usr/local/bin/yarr -addr "0.0.0.0:7070" -db "/data/yarr.db" -auth "${YARR_AUTH_USER}:${YARR_AUTH_PASSWORD}"
