#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=basic-memory
port=8000
image=ghcr.nju.edu.cn/basicmachines-co/basic-memory:latest
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
--user $(id -u):$(id -g) \
--network=$docker_network_name --network-alias=${container_name} \
--hostname=${container_name} \
-v ${base_data_dir}/${container_name}/config:/home/appuser/.basic-memory:rw \
-v ${base_data_dir}/${container_name}/data:/app/data:rw \
-e BASIC_MEMORY_DEFAULT_PROJECT=main \
-e BASIC_MEMORY_SYNC_CHANGES=true \
-e BASIC_MEMORY_LOG_LEVEL=INFO \
-e BASIC_MEMORY_SYNC_DELAY=1000 \
--health-cmd="basic-memory --version" \
--health-interval=30s \
--health-timeout=10s \
--health-retries=3 \
--health-start-period=30s \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image} basic-memory mcp --transport sse --host 0.0.0.0 --port $port


