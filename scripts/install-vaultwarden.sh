#! /bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=vaultwarden
image=vaultwarden/server:latest
port=80

`dirname $0`/create-dir.sh $base_data_dir/${container_name}
`dirname $0`/create-dir.sh $base_data_dir/${container_name}/data

docker pull ${image}


`dirname $0`/stop-container.sh ${container_name}

docker run -d --name ${container_name} \
--restart=always \
-e TZ="Asia/Shanghai" \
-e SIGNUPS_ALLOWED="true" \
-m 256M \
-e LANG="zh_CN.UTF-8" \
-u $(id -u):$(id -g) \
--network=$docker_network_name --network-alias=${container_name} \
-v $base_data_dir/vaultwarden/data:/data/  \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image}