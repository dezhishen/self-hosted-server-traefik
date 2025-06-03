# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
image=lscr.io/linuxserver/sonarr
container_name=sonarr
port=8989

`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
--restart=always \
-m 128M --memory-swap=256M \
--network=$docker_network_name \
--network-alias=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/sonarr/config:/config \
-v $base_data_dir/public/downloads:/downloads \
-v $base_data_dir/public/:/data \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image}

echo "启动sonarr容器"
echo "访问 https://sonarr.$domain "