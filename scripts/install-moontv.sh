#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=moontv
port=3000
image=ghcr.io/senshinya/moontv:latest

MOONTV_PASSWORD=$(`dirname $0`/get-args.sh MOONTV_PASSWORD 密码)
if [ -z "$MOONTV_PASSWORD" ]; then
    read -p "请输入密码:" MOONTV_PASSWORD
    if [ -z "$MOONTV_PASSWORD" ]; then
        echo "随机生成密码"
        MOONTV_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh MOONTV_PASSWORD "$MOONTV_PASSWORD"
fi

echo "密码: $MOONTV_PASSWORD"
REDIS_PASSWORD_SET=$(`dirname $0`/get-args.sh REDIS_PASSWORD_SET "是否设置了Redis密码")
if [ $REDIS_PASSWORD_SET = "y" ]; then 
    REDIS_PASSWORD=$(`dirname $0`/get-args.sh REDIS_PASSWORD "Redis密码")
fi
MOONTV_REDIS_DBINDEX=$(`dirname $0`/get-args.sh MOONTV_REDIS_DBINDEX "请输入MOONTV使用的redis db")
if [ -z "$MOONTV_REDIS_DBINDEX" ]; then
    read -p "请输入MOONTV使用的redis db:" MOONTV_REDIS_DBINDEX
    if [ -z "$MOONTV_REDIS_DBINDEX" ]; then
        echo "未输入redis的db，将使用默认值0"
        MOONTV_REDIS_DBINDEX=6379
    fi
    `dirname $0`/set-args.sh MOONTV_REDIS_DBINDEX ${MOONTV_REDIS_DBINDEX}
fi
if [ -z "$REDIS_PASSWORD" ]; then
    REDIS_URL="redis://redis:6379/${MOONTV_REDIS_DBINDEX}"
else
    REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379/${MOONTV_REDIS_DBINDEX}"
fi


`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-m 128M --memory-swap 256M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e USERNAME=admin \
-e PASSWORD=${MOONTV_PASSWORD} \
-e NEXT_PUBLIC_STORAGE_TYPE=redis \
-e NEXT_PUBLIC_ENABLE_REGISTER=false \
-e REDIS_URL=${REDIS_URL} \
--network=$docker_network_name --network-alias=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}

