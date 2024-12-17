# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=cloudbak
image=likeflyme/cloudbak

docker pull ${image}
port=9527
`dirname $0`/stop-container.sh ${container_name}

docker run  \
--hostname ${container_name} \
--name=${container_name} \
--restart=always -d \
-e PUID=`id -u` -e PGID=`id -g` \
-m 512M \
--network=$docker_network_name \
--network-alias=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-v $base_data_dir/${container_name}/data:/app/data \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image}