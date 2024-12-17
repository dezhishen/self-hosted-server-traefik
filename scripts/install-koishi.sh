#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=koishi
port=5140
image=koishijs/koishi:latest
docker pull $image
`dirname $0`/stop-container.sh ${container_name}
docker run --hostname=${container_name} --name=${container_name} \
  -d \
  -it --restart=always \
  -m 512M \
  -e TZ="Asia/Shanghai" \
  -e LANG="zh_CN.UTF-8" \
  --network=$docker_network_name --network-alias=${container_name} \
  -v ${base_data_dir}/${container_name}/data:/koishi \
  --device /dev/dri --shm-size=512M --privileged \
  --label "traefik.enable=true" \
  --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
  --label "traefik.http.routers.${container_name}.tls=${tls}" \
  --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
  --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
  --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}