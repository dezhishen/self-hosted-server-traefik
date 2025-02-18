#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=iptv-checker
port=8089 
image=zmisgod/iptvchecker

docker pull ${image}

`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
-d --restart=always \
-e PUID=`id -u` -e PGID=`id -g` \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} \
-v ${base_data_dir}/${container_name}/output:/app/static/output \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}
