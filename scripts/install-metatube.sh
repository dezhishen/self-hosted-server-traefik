# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=metatube
port=8080
image=ghcr.io/metatube-community/metatube-server
#linuxserver/lidarr:latest
mkdir -p ${base_data_dir}/${container_name}/config 
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
--restart=always \
-m 512M --memory-swap=1G \
--network=$docker_network_name \
--network-alias=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/${container_name}/config:/config \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" ${image} -dsn /config/metatube.db
