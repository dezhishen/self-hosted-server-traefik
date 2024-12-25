#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=redroid
image=redroid/redroid:12.0.0_64only-latest
port=5555 
docker pull $image
`dirname $0`/stop-container.sh ${container_name}
docker run --restart=always -itd --privileged  --name ${container_name} \
-p ${port}:${port} \
-v ${base_data_dir}/${container_name}/data:/data \
--network=${docker_network_name} --network-alias=${container_name} \
${image}