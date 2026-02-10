# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=jellyfin
image=linuxserver/jellyfin:latest
port=8096
# 是否重装jellyfin
  docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}
    video_gid=$(cat /etc/group | grep -e video | cut -d ":" -f 3)
    render_gid=$(cat /etc/group | grep -e render | cut -d ":" -f 3)
    docker run  \
    --hostname ${container_name} \
    --privileged --restart=always -d \
    --device /dev/dri \
    -e PUID=`id -u` -e PGID=`id -g` \
    --name=${container_name} \
    -m 1024M \
    --network=$docker_network_name \
    --network-alias=${container_name} \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    -v $base_data_dir/jellyfin/config:/config \
    -v $base_data_dir/public/:/data \
    -p ${port}:${port} \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
    --label "traefik.enable=true" \
    ${image}
