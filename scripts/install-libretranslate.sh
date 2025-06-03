# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=libretranslate
image=libretranslate/libretranslate:latest

docker pull ${image}
port=5000
`dirname $0`/stop-container.sh ${container_name}
docker run  \
-m 512M  --name=${container_name} \
--hostname ${container_name} \
--restart=always -d \
--device /dev/dri \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e LT_API_KEYS=true -e LT_REQ_LIMIT=100 \
-e LT_HOST=0.0.0.0 \
-e LT_LOAD_ONLY='en,zh,ja' \
--network=$docker_network_name \
--network-alias=${container_name} \
-v $base_data_dir/${container_name}/models:/home/libretranslate/.local:rw \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image}
