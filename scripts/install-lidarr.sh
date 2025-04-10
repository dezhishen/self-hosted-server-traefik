# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=lidarr
port=8686
image=linuxserver/lidarr:latest

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
mkdir -p $base_data_dir/${container_name}/init/init-lidarr-resource
echo """
#!/usr/bin/with-contenv bash
# shellcheck shell=bash
ln -s /app/lidarr/bin/Localization/Core/zh.json/zh_CN.json /app/lidarr/bin/Localization/Core/zh.json/zh.json > /dev/null
""" > $base_data_dir/${container_name}/init/init-lidarr-resource/run
echo "oneshot" > $base_data_dir/${container_name}/init/init-lidarr-resource/type
echo "up" > /etc/s6-overlay/s6-rc.d/init-lidarr-resource/run
docker run -d --name=${container_name} \
--restart=always \
-m 512M --memory-swap=1G \
--network=$docker_network_name \
--network-alias=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/${container_name}/config:/config \
-v $base_data_dir/${container_name}/init/init-lidarr-resource:/etc/s6-overlay/s6-rc.d/init-lidarr-resource \
-v $base_data_dir/public/downloads:/downloads \
-v $base_data_dir/public/:/data \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" ${image}
