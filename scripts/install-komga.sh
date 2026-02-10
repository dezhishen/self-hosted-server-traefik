#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=komga
port=25600
image=gotson/komga

mkdir -p ${base_data_dir}/${container_name}/config
mkdir -p ${base_data_dir}/${container_name}/data

docker pull ${image}

`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
  -d --restart=always \
  -m 512M \
  --user $(id -u):$(id -g) \
  -e TZ="Asia/Shanghai" \
  -e LANG="zh_CN.UTF-8" \
  -v ${base_data_dir}/public/9kg/comics:/data/9kg:ro \
  -v ${base_data_dir}/${container_name}/config:/config \
  --network=$docker_network_name --network-alias=${container_name} \
  --hostname=${container_name} \
  --label "traefik.enable=true" \
  --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
  --label "traefik.http.routers.${container_name}.tls=${tls}" \
  --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
  --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
  --label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}

