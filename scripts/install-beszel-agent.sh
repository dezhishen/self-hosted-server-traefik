# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=beszel-agent
image=henrygd/beszel-agent
port=45876

docker pull $image

`dirname $0`/stop-container.sh ${container_name}

docker run -d --name=${container_name} \
--restart=always \
--network=$docker_network_name \
--network-alias=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PORT=45876 \
-e KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBW46jEI5AIRIVTNYTk1bnCWXQplc0EtHxFfWMroSXE" \
-m 64M \
-v /var/run/docker.sock:/var/run/docker.sock:ro \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
$image
