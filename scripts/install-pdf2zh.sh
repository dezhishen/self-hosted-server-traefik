#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=pdf2zh
port=7860 
image=byaidu/pdf2zh
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-m 256M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} \
--hostname=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}
