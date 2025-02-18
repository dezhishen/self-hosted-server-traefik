# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

`dirname $0`/stop-container.sh radarr
docker run -d --name=radarr \
--restart=always \
-m 128M --memory-swap=256M \
--network=$docker_network_name \
--network-alias=radarr \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/radarr/config:/config \
-v $base_data_dir/public/downloads:/downloads \
-v $base_data_dir/public/:/data \
--label 'traefik.http.routers.radarr.rule=Host(`radarr'.$domain'`)' \
--label "traefik.http.routers.radarr.tls=${tls}" \
--label "traefik.http.routers.radarr.tls.certresolver=traefik" \
--label "traefik.http.routers.radarr.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.radarr.loadbalancer.server.port=7878" \
--label "traefik.enable=true" \
lscr.io/linuxserver/radarr

echo "启动radarr容器"
echo "访问 https://radarr.$domain "