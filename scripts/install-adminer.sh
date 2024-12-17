#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=adminer
image=library/adminer
port=8080

docker pull $image
docker stop $container_name > /dev/null
docker rm $container_name
docker run --restart=always -d --name ${container_name} -m 128M \
    --user=`id -u`:`id -g` \
    -v ${base_data_dir}/${container_name}/data:/data \
    --network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name} \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
    --label "traefik.enable=true" \
${image}
