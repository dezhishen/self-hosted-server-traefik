# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

`dirname $0`/stop-container.sh readarr
docker run -d --name=readarr \
--restart=always \
-m 64M --memory-swap=128M \
--network=$docker_network_name \
--network-alias=readarr \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/readarr/config:/config \
-v $base_data_dir/public/downloads:/downloads \
-v $base_data_dir/public/:/data \
--label 'traefik.http.routers.readarr.rule=Host(`readarr'.$domain'`)' \
--label "traefik.http.routers.readarr.tls=${tls}" \
--label "traefik.http.routers.readarr.tls.certresolver=traefik" \
--label "traefik.http.routers.readarr.tls.domains[0].main=readarr.$domain" \
--label "traefik.http.services.readarr.loadbalancer.server.port=8787" \
--label "traefik.enable=true" \
lscr.io/linuxserver/readarr

echo "启动lidarr容器"
echo "访问 https://readarr.$domain "