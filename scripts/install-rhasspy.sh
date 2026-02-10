# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=rhasspy
port=12101
image=rhasspy/rhasspy:latest

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
--restart=always \
-m 512M --memory-swap=1G \
--network=$docker_network_name \
--network-alias=${container_name} \
--device /dev/snd:/dev/snd \
-v "/etc/localtime:/etc/localtime:ro" \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e VIRTUAL_HOST="" \
-e VOSK_SERVER=http://vosk:2700 \
-v $base_data_dir/${container_name}/profiles:/profiles \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" ${image} \
--user-profiles /profiles \
      --profile zh
