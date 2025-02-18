#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=ttyd
image=wettyoss/wetty
# 从容器网络中获取网络网关地址，使用.分割，获取前三个端，拼接1
remote_ip=`docker network inspect traefik --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' | awk -F'.' '{print $1"."$2"."$3"."1}'`
docker pull ${image}
TTYD_AUTH_USER=$(`dirname $0`/get-args.sh TTYD_AUTH_USER 用户名)
if [ -z "$TTYD_AUTH_USER" ]; then
    read -p "请输入用户名:" TTYD_AUTH_USER
    if [ -z "$TTYD_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        TTYD_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh TTYD_AUTH_USER "$TTYD_AUTH_USER"
fi

TTYD_AUTH_PASSWORD=$(`dirname $0`/get-args.sh TTYD_AUTH_PASSWORD 密码)
if [ -z "$TTYD_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" TTYD_AUTH_PASSWORD
    if [ -z "$TTYD_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        TTYD_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh TTYD_AUTH_PASSWORD "$TTYD_AUTH_PASSWORD"
fi

echo "用户名: $TTYD_AUTH_USER"
echo "密码: $TTYD_AUTH_PASSWORD"
digest="$(printf "%s:%s:%s" "$TTYD_AUTH_USER" "traefik" "$TTYD_AUTH_PASSWORD" | md5sum | awk '{print $1}' )"
userlist=$(printf "%s:%s:%s\n" "$TTYD_AUTH_USER" "traefik" "$digest")
docker rm -f $container_name
docker run --name=${container_name} \
--restart=always -d \
-m 64M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e UID=`id -u` \
-v ${base_data_dir}/${container_name}/data:/data \
-e GID=`id -g` \
--network=$docker_network_name --network-alias=$docker_network_name \
--label 'traefik.http.routers.'$container_name'.rule=Host(`'$container_name.$domain'`)' \
--label "traefik.http.routers.$container_name.tls=${tls}" \
--label "traefik.http.routers.$container_name.service=$container_name" \
--label "traefik.http.routers.$container_name.tls.certresolver=traefik" \
--label "traefik.http.routers.$container_name.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.$container_name.loadbalancer.server.port=3000" \
--label "traefik.http.middlewares.$container_name-auth.digestauth.users=$userlist" \
--label "traefik.http.routers.$container_name.middlewares=$container_name-auth@docker" \
--label "traefik.enable=true" \
${image} --ssh-host=${remote_ip} 
