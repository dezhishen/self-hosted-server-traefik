#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=wakapi
image=ghcr.io/muety/wakapi:latest
port=3000 

WAKAPI_PASSWORD_SALT=$(`dirname $0`/get-args.sh WAKAPI_PASSWORD_SALT 密码盐)
if [ -z "$WAKAPI_PASSWORD_SALT" ]; then
    read -p "请输入密码盐:" WAKAPI_PASSWORD_SALT
    if [ -z "$WAKAPI_PASSWORD_SALT" ]; then
        echo "随机生成密码盐"
        WAKAPI_PASSWORD_SALT="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1)"
        echo "随机盐为：${WAKAPI_PASSWORD_SALT}"
    fi
    `dirname $0`/set-args.sh WAKAPI_PASSWORD_SALT "$WAKAPI_PASSWORD_SALT"
fi
MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST "mysql主机" )
MYSQL_PORT=$(`dirname $0`/get-args.sh MYSQL_PORT "mysql端口" )
MYSQL_USER=$(`dirname $0`/get-args.sh MYSQL_USER "mysql用户名" )
MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "mysql密码" )
MYSQL_DB_NAME=wakapi
if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_DB_NAME" ] || [ -z "$MYSQL_USER" ]; then
    echo "未输入mysql主机、密码、数据库名或用户名，退出安装。"
    exit 1
fi

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-m 128M \
-d --restart=always \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e WAKAPI_DB_TYPE=mysql \
-e WAKAPI_DB_HOST=${MYSQL_HOST} \
-e WAKAPI_DB_PORT=${MYSQL_PORT} \
-e WAKAPI_DB_NAME=${MYSQL_DB_NAME} \
-e WAKAPI_DB_USER=${MYSQL_USER} \
-e WAKAPI_DB_PASSWORD=${MYSQL_PASSWORD} \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-v ${base_data_dir}/${container_name}/data:/data \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
