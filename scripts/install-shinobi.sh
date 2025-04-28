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
if [ ! -d ${base_data_dir}/${container_name}/customAutoLoad ]; then
    mkdir -p ${base_data_dir}/${container_name}/customAutoLoad
fi
if [ ! -d ${base_data_dir}/${container_name}/plugins ]; then
    mkdir -p ${base_data_dir}/${container_name}/plugins
fi
if [ ! -d ${base_data_dir}/public/record/videos ]; then
    mkdir -p ${base_data_dir}/public/record/videos
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
    -v /dev/shm/shinobi/streams:/dev/shm/streams:rw \
    --device-cgroup-rule='c 189:* rmw' \
    --device /dev/dri:/dev/dri \
    -v ${base_data_dir}/${container_name}/config:/config:rw \
    -v ${base_data_dir}/${container_name}/customAutoLoad:/home/Shinobi/libs/customAutoLoad:rw \
    -v ${base_data_dir}/${container_name}/plugins:/home/Shinobi/plugins:rw \
    -v ${base_data_dir}/public/record/videos:/home/Shinobi/videos:rw \
    -v /etc/localtime:/etc/localtime:ro \
    --network=${docker_network_name} --network-alias=${container_name} \
    --hostname=${container_name} \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.${pre}.service=${pre}" \
    --label 'traefik.http.routers.'${pre}'.rule=Host(`'${pre}''.$domain'`)' \
    --label "traefik.http.routers.${pre}.tls=${tls}" \
    --label "traefik.http.routers.${pre}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${pre}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${pre}.loadbalancer.server.port=${port}" \
${image}