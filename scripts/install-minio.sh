#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

set -e

container_name=minio
version=latest
image=minio/minio:${version}
api_port=9000
console_port=9001

MINIO_ROOT_USER=$(`dirname $0`/get-args.sh MINIO_ROOT_USER "管理员用户名")
if [ -z "$MINIO_ROOT_USER" ]; then
    read -p "请输入管理员用户名:" MINIO_ROOT_USER
    if [ -z "$MINIO_ROOT_USER" ]; then
        echo "输入不能为空"
        exit 1
    fi
    `dirname $0`/set-args.sh "${MINIO_ROOT_USER}" "${MINIO_ROOT_USER}"
fi

MINIO_ROOT_PASSWORD=$(`dirname $0`/get-args.sh MINIO_ROOT_PASSWORD "管理员密码")
if [ -z "$MINIO_ROOT_PASSWORD" ]; then
    read -p "请输入管理员密码:" MINIO_ROOT_PASSWORD
    if [ -z "$MINIO_ROOT_PASSWORD" ]; then
        echo "输入不能为空"
        exit 1
    fi
    `dirname $0`/set-args.sh MINIO_ROOT_PASSWORD "${MINIO_ROOT_PASSWORD}"
fi

mkdir -p ${base_data_dir}/${container_name}/${version}/data

MINIO_PORT_MAPPING=$(`dirname $0`/get-args.sh MINIO_PORT_MAPPING "是否映射端口[y/n]")
if [ -z "$MINIO_PORT_MAPPING" ]; then
    read -p "是否映射端口[y/n]:" MINIO_PORT_MAPPING
    if [ -z "$MINIO_PORT_MAPPING" ]; then
        echo "是否映射端口[y/n]为空 默认不映射端口"
        MINIO_PORT_MAPPING="n"
    fi
    `dirname $0`/set-args.sh MINIO_PORT_MAPPING "${MINIO_PORT_MAPPING}"
fi

docker pull ${image} > /dev/null 2>&1 || true
docker stop ${container_name} > /dev/null 2>&1 || true
docker rm ${container_name} > /dev/null 2>&1 || true
mkdir -p ${base_data_dir}/${container_name}/${version}/data

docker run --restart=always -d --name ${container_name} -m 512M \
--user $(id -u):$(id -g) \
-e TZ=Asia/Shanghai \
-e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 \
-e MINIO_ROOT_USER=${MINIO_ROOT_USER} \
-e MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD} \
`if [ "$MINIO_PORT_MAPPING" = "y" ]; then echo "-p ${api_port}:9000 -p ${console_port}:9001"; fi` \
-v ${base_data_dir}/${container_name}/${version}/data:/data \
--network=${docker_network_name} --network-alias=${container_name} \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${console_port}" \
--label "traefik.enable=true" \
${image} server /data --console-address ":9001"

echo "MinIO 启动成功"
echo "设置 MINIO_ENDPOINT 为 ${container_name}:9000"
`dirname $0`/set-args.sh MINIO_ENDPOINT "${container_name}:9000"
