#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=gotify
image=gotify/server
port=80
docker pull ${image}
docker stop $container_name > /dev/null
docker rm $container_name

docker run --name=${container_name} \
-d --restart=always \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-m 64M \
-v ${base_data_dir}/${container_name}/data:/app/data \
--network=${docker_network_name} --network-alias=${container_name} \
--label "traefik.enable=true" \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.http.routers.${container_name}.service=${container_name}" \
${image}
