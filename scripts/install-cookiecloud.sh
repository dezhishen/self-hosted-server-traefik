#! /bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container=cookiecloud
image="easychen/cookiecloud:latest"
port=8088

docker pull $image
`dirname $0`/stop-container.sh $container

docker run -d --restart unless-stopped \
-e TZ="Asia/Shanghai" \
-e HOST=0.0.0.0 \
-e LANG="zh_CN.UTF-8" \
-m 64M \
--network=$docker_network_name --network-alias=$container \
--name $container \
--label 'traefik.http.routers.'$container'.rule=Host(`'$container.$domain'`)' \
--label "traefik.http.routers.$container.tls=${tls}" \
--label "traefik.http.routers.$container.tls.certresolver=traefik" \
--label "traefik.http.routers.$container.tls.domains[0].main=$container.$domain" \
--label "traefik.http.services.$container.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
 $image
