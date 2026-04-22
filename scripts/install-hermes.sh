#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=hermes
image=nousresearch/hermes-agent:latest
port=9119

mkdir -p ${base_data_dir}/${container_name}/data

video_gid=$(getent group video | cut -d ":" -f 3)
render_gid=$(getent group render | cut -d ":" -f 3)

read -p "是否需要重装gateway？(y/n) " reinstall_gateway
case "$reinstall_gateway" in
    y|Y )
    docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}
    docker run --name=${container_name} \
        -d --restart=always \
        -m 2G \
        -e TZ="Asia/Shanghai" \
        -e LANG="zh_CN.UTF-8" \
        -v ${base_data_dir}/${container_name}/data:/opt/data \
        --network=${docker_network_name} --network-alias=${container_name} \
        --hostname=${container_name} \
        --shm-size=1g \
        --device /dev/dri:/dev/dri \
        --group-add ${video_gid} \
        --group-add ${render_gid} \
    ${image} gateway run
    ;;
esac

read -p "是否需要运行dashboard？(y/n) " run_dashboard
case "$run_dashboard" in
    y|Y )
    docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}-dashboard
    gateway_url=http://${container_name}:8642
    docker run --name=${container_name}-dashboard \
        -d --restart=always \
        -e TZ="Asia/Shanghai" \
        -e LANG="zh_CN.UTF-8" \
        -e GATEWAY_HEALTH_URL=${gateway_url} \
        -v ${base_data_dir}/${container_name}/data:/opt/data \
        --network=${docker_network_name} --network-alias=${container_name}-dashboard \
        --hostname=${container_name}-dashboard \
        --label "traefik.enable=true" \
        --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
        --label "traefik.http.routers.${container_name}.tls=${tls}" \
        --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
        --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
        --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
        ${image} dashboard --host 0.0.0.0 --insecure
    ;;
esac
