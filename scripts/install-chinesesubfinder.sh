# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=chinesesubfinder
image='allanpk716/chinesesubfinder:latest-lite'

port=19035

docker pull $image

`dirname $0`/stop-container.sh ${container_name} #chinesesubfinder

docker run -d \
--restart=always \
--name=${container_name} \
-m 128M --memory-swap=256M \
--network=$docker_network_name \
--network-alias=${container_name} \
--hostname=${container_name} \
-e PERMS=false \
-e UMASK='022' \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/${container_name}/config:/config \
-v $base_data_dir/public/:/media \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image}
#allanpk716/chinesesubfinder:latest@sha256:df6c51a5170b40af81ec7dc4e3f3679b02cb0969b2eb7d1d908bb34b50b525a7

