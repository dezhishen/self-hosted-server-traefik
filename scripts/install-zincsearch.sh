#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=zincsearch
image=public.ecr.aws/zinclabs/zincsearch:latest
port=4080

ZINCSEARCH_AUTH_USER=$(`dirname $0`/get-args.sh ZINCSEARCH_AUTH_USER 用户名)
if [ -z "$ZINCSEARCH_AUTH_USER" ]; then
    read -p "请输入用户名:" ZINCSEARCH_AUTH_USER
    if [ -z "$ZINCSEARCH_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        ZINCSEARCH_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh ZINCSEARCH_AUTH_USER "$ZINCSEARCH_AUTH_USER"
fi

ZINCSEARCH_AUTH_PASSWORD=$(`dirname $0`/get-args.sh ZINCSEARCH_AUTH_PASSWORD 密码)
if [ -z "$ZINCSEARCH_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" ZINCSEARCH_AUTH_PASSWORD
    if [ -z "$ZINCSEARCH_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        ZINCSEARCH_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh ZINCSEARCH_AUTH_PASSWORD "$ZINCSEARCH_AUTH_PASSWORD"
fi


echo "用户名: $ZINCSEARCH_AUTH_USER"
echo "密码: $ZINCSEARCH_AUTH_PASSWORD"

docker pull ${image}

`dirname $0`/stop-container.sh ${container_name}

docker run -d --restart=always \
--name=${container_name} \
--user `id -u`:`id -g` \
-m 128M --memory-swap 256M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e ZINC_FIRST_ADMIN_USER=admin \
-e ZINC_FIRST_ADMIN_PASSWORD=Sdz123456789 \
-e ZINC_DATA_PATH="/data" \
--network=$docker_network_name \
--network-alias=${container_name} \
--hostname=${container_name} \
-v ${base_data_dir}/${container_name}/data:/data \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}

echo "设置 ZINCSEARCH_HOST=${container_name}"
`dirname $0`/set-args.sh ZINCSEARCH_HOST ${container_name}

echo "设置 ZINCSEARCH_PORT=${port}"
`dirname $0`/set-args.sh ZINCSEARCH_PORT ${port}

