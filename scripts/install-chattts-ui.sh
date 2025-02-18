#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=chattts-ui
image=dezhishen/chattts-ui  #xhofe/alist
port=9966
mkdir -p ${base_data_dir}/${container_name}/data
chmod -R `id -u`:`id -g` ${base_data_dir}/${container_name}/data
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
--user `id -u`:`id -g` \
--privileged  --device /dev/dri \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e LOG_LEVEL="INFO" \
-e WEB_ADDRESS="0.0.0.0:9966" \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-v ${base_data_dir}/${container_name}/data:/data \
-v /dev/dri/by-path:/dev/dri/by-path \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
