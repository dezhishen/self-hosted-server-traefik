#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=root
port=80
image=nginx:alpine

ROOT_AUTH_USER=$(`dirname $0`/get-args.sh ROOT_AUTH_USER 用户名)
if [ -z "$ROOT_AUTH_USER" ]; then
    read -p "请输入用户名:" ROOT_AUTH_USER
    if [ -z "$ROOT_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        ROOT_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh ROOT_AUTH_USER "$ROOT_AUTH_USER"
fi

ROOT_AUTH_PASSWORD=$(`dirname $0`/get-args.sh ROOT_AUTH_PASSWORD 密码)
if [ -z "$ROOT_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" ROOT_AUTH_PASSWORD
    if [ -z "$ROOT_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        ROOT_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh ROOT_AUTH_PASSWORD "$ROOT_AUTH_PASSWORD"
fi

echo "用户名: $ROOT_AUTH_USER"
echo "密码: $ROOT_AUTH_PASSWORD"
digest="$(printf "%s:%s:%s" "$ROOT_AUTH_USER" "traefik" "$ROOT_AUTH_PASSWORD" | md5sum | awk '{print $1}' )"
userlist=$(printf "%s:%s:%s\n" "$ROOT_AUTH_USER" "traefik" "$digest")



`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-e USER_UID=`id -u` -e USER_GID=`id -g` \
-m 128M --memory-swap 256M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} \
-v ${base_data_dir}/${container_name}/data:/usr/share/nginx/html \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
--label "traefik.http.middlewares.${container_name}-auth.digestauth.users=$userlist" \
--label "traefik.http.routers.${container_name}.middlewares=${container_name}-auth@docker" \
${image}

