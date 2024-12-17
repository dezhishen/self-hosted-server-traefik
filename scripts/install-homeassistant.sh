#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=homeassistant

`dirname $0`/stop-container.sh ${container_name}
docker pull homeassistant/home-assistant:latest

docker run --name=${container_name} \
-m 1G -d --privileged \
--network=host  \
-v /dev/net/tun:/dev/net/tun \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-e PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple \
-v ${base_data_dir}/${container_name}/config:/config \
homeassistant/home-assistant:latest