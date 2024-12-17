# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=nas-tools
port=3000
image=hsuyelin/nas-tools
docker ps -a -q --filter "name=$container_name" | grep -q . && docker rm -fv $container_name
docker pull $image 
docker run -d \
    --name $container_name \
    --restart=always \
    -m 512M --memory-swap 1024M \
    -e LANG=zh_CN.UTF-8 \
    -e TZ=Asia/Shanghai \
    -e PUID=`id -u` \
    -e PGID=`id -g` \
    -e UMASK=022 \
    -e NASTOOL_AUTO_UPDATE=false \
    -v $base_data_dir/${container_name}/config:/config \
    -v $base_data_dir/public/:/data \
    -v $base_data_dir/public/downloads:/downloads \
    --network=$docker_network_name \
    --network-alias=${container_name} \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
    --label "traefik.enable=true" \
$image

