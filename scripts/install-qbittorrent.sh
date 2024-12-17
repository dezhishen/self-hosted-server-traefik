# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
image=linuxserver/qbittorrent
port=8080
docker_container_name=qbittorrent
#`dirname $0`/create-dir.sh $base_data_dir/qbittorrent
#`dirname $0`/create-dir.sh $base_data_dir/qbittorrent/config
docker pull ${image}

`dirname $0`/stop-container.sh ${docker_container_name}

docker run -d --name=${docker_container_name} \
--restart=always \
-m 1G \
--network=host \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/${docker_container_name}/config:/config \
-v $base_data_dir/public/downloads:/data/downloads \
-v $base_data_dir/${docker_container_name}/incomplete-torrents:/incomplete-torrents \
-v $base_data_dir/${docker_container_name}/finished-torrents:/finished-torrents \
${image}


