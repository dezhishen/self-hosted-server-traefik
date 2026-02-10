#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=openlist
image=openlistteam/openlist:latest-lite
#latest #ghcr.io/openlistteam/openlist-git
port=5244
s3_port=5246
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-m 128M \
-d --restart=always \
--user $(id -u):$(id -g) \
-p 5246:5246 \
-e UMASK=022 \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-v ${base_data_dir}/${container_name}/data:/opt/openlist/data \
-v ${base_data_dir}/${container_name}/strm:/strm \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.http.routers.${container_name}.service=${container_name}" \
--label 'traefik.http.routers.'${container_name}'-s3.rule=Host(`'${container_name}-s3.$domain'`)' \
--label "traefik.http.routers.${container_name}-s3.tls=${tls}" \
--label "traefik.http.routers.${container_name}-s3.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}-s3.tls.domains[0].main=${container_name}-s3.$domain" \
--label "traefik.http.services.${container_name}-s3.loadbalancer.server.port=${s3_port}" \
--label "traefik.http.routers.${container_name}-s3.service=${container_name}-s3" \
${image}
