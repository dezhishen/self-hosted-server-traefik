#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=audiobookshelf
image=ghcr.io/advplyr/audiobookshelf:latest
port=80
mkdir -p ${base_data_dir}/${container_name}/config
mkdir -p ${base_data_dir}/${container_name}/metadata
mkdir -p ${base_data_dir}/public/audiobooks
mkdir -p ${base_data_dir}/public/podcasts
docker pull $image
docker stop $container_name > /dev/null
docker rm $container_name
docker run --restart=always -d --name ${container_name} -m 128M \
    --user=`id -u`:`id -g` \
    -v ${base_data_dir}/public/audiobooks:/audiobooks \
    -v ${base_data_dir}/public/podcasts:/podcasts \
    -v ${base_data_dir}/${container_name}/config:/config \
    -v ${base_data_dir}/${container_name}/metadata:/metadata \
    --network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name} \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
    --label "traefik.enable=true" \
${image}
