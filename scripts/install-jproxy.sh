# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=jproxy
image=luckypuppy514/jproxy:latest
port=8117

docker pull $image

`dirname $0`/stop-container.sh ${container_name}

docker run -d --name=${container_name} \
--restart=always \
--network=$docker_network_name \
--network-alias=${container_name} \
-m 600M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-e JAVA_OPTS="-Xms512m -Xmx512m" \
-v $base_data_dir/${container_name}/database:/app/database \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
$image
