#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=shinobi
image=registry.gitlab.com/shinobi-systems/shinobi:latest-no-db 
port=8080

if [ ! -d ${base_data_dir}/${container_name}/ ]; then
    mkdir -p ${base_data_dir}/${container_name}/
fi
if [ ! -d ${base_data_dir}/${container_name}/config ]; then
    mkdir -p ${base_data_dir}/${container_name}/config
fi
if [ ! -d ${base_data_dir}/${container_name}/data ]; then
    mkdir -p ${base_data_dir}/${container_name}/data
fi
if [ ! -d ${base_data_dir}/public/record/videos ]; then
    mkdir -p ${base_data_dir}/public/record/videos
fi
MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST "mysql主机" )
MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "mysql密码" )
MYSQL_DB_NAME=shinobi
MYSQL_USER=$(`dirname $0`/get-args.sh MYSQL_USER "mysql用户名" )
if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_DB_NAME" ] || [ -z "$MYSQL_USER" ]; then
    echo "未输入mysql主机、密码、数据库名或用户名，退出安装。"
    exit 1
fi
docker pull $image
docker stop $container_name > /dev/null
docker rm $container_name

docker run \
    --restart=unless-stopped -d \
    --name ${container_name} \
    -m 512M \
    --user=`id -u`:`id -g` \
    -e TZ=Asia/Shanghai \
    -e LANG=zh_CN.UTF-8 \
    -e HOME=/data \
    -e DB_HOST=${MYSQL_HOST} \
    -e DB_USER=${MYSQL_USER} \
    -e DB_PASSWORD=${MYSQL_PASSWORD} \
    -e DB_DATABASE=${MYSQL_DB_NAME} \
    -e SHINOBI_UPDATE=false \
    -v /dev/shm/shinobi/streams:/dev/shm/streams:rw \
    --device-cgroup-rule='c 189:* rmw' \
    --device /dev/dri:/dev/dri \
    -v ${base_data_dir}/${container_name}/config:/config \
    -v ${base_data_dir}/${container_name}/data:/data \
    -v ${base_data_dir}/public/record/videos:/data/videos:rw \
    -v ${base_data_dir}/public/record/videos:/videos:rw \
    -v /etc/localtime:/etc/localtime:ro \
    --network=${docker_network_name} --network-alias=${container_name} \
    --hostname=${container_name} \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.${container_name}.service=${container_name}" \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}''.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}