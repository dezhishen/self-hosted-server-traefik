#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=qinglong
image="whyour/qinglong"
port="5700"
`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
-d --restart=always \
-e PUID=`id -u` -e PGID=`id -g` \
-m 256M \
-e UMASK=022 \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} \
-v ${base_data_dir}/${container_name}/config:/ql/config \
-v ${base_data_dir}/${container_name}/data:/ql/data \
-v ${base_data_dir}/${container_name}/db:/ql/db \
-v ${base_data_dir}/${container_name}/jbot:/ql/jbot \
-v ${base_data_dir}/${container_name}/log:/ql/log \
-v ${base_data_dir}/${container_name}/repo:/ql/repo \
-v ${base_data_dir}/${container_name}/scripts:/ql/scripts \
-v ${base_data_dir}:${base_data_dir} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
