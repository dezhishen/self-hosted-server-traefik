#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=alist
image=xhofe/alist  #xhofe/alist
port=5244

ALIST_AUTH_USER=$(`dirname $0`/get-args.sh ALIST_AUTH_USER 用户名)
if [ -z "$ALIST_AUTH_USER" ]; then
    read -p "请输入用户名:" ALIST_AUTH_USER
    if [ -z "$ALIST_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        ALIST_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh ALIST_AUTH_USER "$ALIST_AUTH_USER"
fi

ALIST_AUTH_PASSWORD=$(`dirname $0`/get-args.sh ALIST_AUTH_PASSWORD 密码)
if [ -z "$ALIST_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" ALIST_AUTH_PASSWORD
    if [ -z "$ALIST_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        ALIST_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh ALIST_AUTH_PASSWORD "$ALIST_AUTH_PASSWORD"
fi


echo "用户名: $ALIST_AUTH_USER"
echo "密码: $ALIST_AUTH_PASSWORD"
digest="$(printf "%s:%s:%s" "$ALIST_AUTH_USER" "traefik" "$ALIST_AUTH_PASSWORD" | md5sum | awk '{print $1}' )"
userlist=$(printf "%s:%s:%s\n" "$ALIST_AUTH_USER" "traefik" "$digest")

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-m 128M \
-d --restart=always \
-e PUID=`id -u` -e PGID=`id -g` \
-e UMASK=022 \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-v ${base_data_dir}/${container_name}/data:/opt/alist/data \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
