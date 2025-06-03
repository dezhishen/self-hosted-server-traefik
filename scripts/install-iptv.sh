#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
container_name=iptv
tls=$4
port=8080
image=herberthe0229/iptv-sources:latest

docker pull ${image}

`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
-d --restart=always \
-m 128M --memory-swap 256M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e ENABLE_IPTV_CHECKER=true \
-e IPTV_CHECKER_URL=https://iptv-checker.${domain} \
--network=$docker_network_name --network-alias=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}
