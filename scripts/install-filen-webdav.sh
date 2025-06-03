# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=filen-webdav
image=dezhishen/filen-webdav:latest
docker pull ${image}
port=8888
`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
--hostname ${container_name} \
-d --restart=always \
-m 128M \
-e TZ="Asia/Shanghai" \
-e HOST="0.0.0.0" \
-e LANG="zh_CN.UTF-8" \
--network=$docker_network_name --network-alias=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
--label "traefik.http.routers.${container_name}.service=${container_name}" \
${image}
