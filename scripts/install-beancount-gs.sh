#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=beancount-gs
image=xdbin/beancount-gs
port=80

docker pull $image
`dirname $0`/stop.sh $container_name
docker run --restart=always -d --name ${container_name} -m 512M \
--user=`id -u`:`id -g` \
-e TZ=Asia/Shanghai \
-e LANG=zh_CN.UTF-8 \
-v ${base_data_dir}/${container_name}/data:/data/beancount:Z \
-v ${base_data_dir}/${container_name}/icons:/app/public/icons:Z \
-v ${base_data_dir}/${container_name}/config:/app/config:Z \
-v ${base_data_dir}/${container_name}/bak:/app/bak:Z \
-v ${base_data_dir}/${container_name}/logs:/app/logs:Z \
-p ${port}:80 \
--network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name} \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image} "sh -c 'cp -rn /app/public/default_icons/* /app/public/icons && ./beancount-gs -p 80'"