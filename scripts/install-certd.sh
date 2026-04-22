#!/bin/bash
#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=certd
port=7001
image=ghcr.io/certd/certd:latest

mkdir -p ${base_data_dir}/certd/data
docker pull $image
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
  -d --restart=always \
  -m 128M --memory-swap 256M \
  -e TZ="Asia/Shanghai" \
  -e LANG="zh_CN.UTF-8" \
  -e certd_koa_hostname="0.0.0.0" \
  --network=$docker_network_name --network-alias=${container_name} \
  --hostname=${container_name} \
  -v ${base_data_dir}/certd/data:/app/data \
  --label "traefik.enable=true" \
  --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
  --label "traefik.http.routers.${container_name}.tls=${tls}" \
  --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
  --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
  --label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}
