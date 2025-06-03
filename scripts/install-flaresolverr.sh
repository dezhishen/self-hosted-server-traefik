# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=flaresolverr
image="ghcr.io/flaresolverr/flaresolverr:latest"
docker pull ${image}
port=8191
`dirname $0`/stop-container.sh ${container_name}
docker run -d \
--restart=always \
--name=flaresolverr \
--network=$docker_network_name \
--network-alias=${container_name} \
--network-alias=proxy_${container_name} \
-e LANG="zh_CN.UTF-8" \
-e TZ="Asia/Shanghai" \
-e LOG_LEVEL=info \
-e TEST_URL="https://www.baidu.com" \
-e BROWSER_TIMEOUT=80000 \
-m 256M --memory-swap=512M \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
