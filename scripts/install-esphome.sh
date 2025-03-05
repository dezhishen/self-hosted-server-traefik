# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=esphome
image=esphome/esphome

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
--restart=always \
--privileged \
-m 128M \
--network=host \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-v $base_data_dir/${container_name}/config:/config \
-v /etc/localtime:/etc/localtime:ro \
${image}
