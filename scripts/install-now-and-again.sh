#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
tag=1.0.7
#-preview
#1-004
container_name=now-and-again
port=8080
image=ghcr.io/dezhishen/now-and-again:${tag}

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
mkdir -p $base_data_dir/${container_name}/data

docker run -d --name=${container_name} \
--restart=always \
-m 256M --memory-swap=512M \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e NA_DATA_DIR=/data \
-e GIN_MODE=release \
--user=$(id -u):$(id -g) \
-v $base_data_dir/${container_name}/data:/data \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" ${image}
