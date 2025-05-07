#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=iyuu
port=8780
read -p "是否使用无数据库版本(y/n):" use_nodb
case $use_nodb in
y|Y|yes|Yes|YES)
    image=dezhishen/iyuuplus-dev-nodb
    echo "ps: 使用无数据库版本，请确保已经安装了mysql或者mariadb"
    echo "安装后，请在界面中配置数据库"
    ;;
*)
    image=iyuucn/iyuuplus-dev
    ;;
esac

# 检查是否安装了qbittorrent
docker inspect qbittorrent > /dev/null 2>&1
qbittorrent_installed=$?
# 检查是否安装了transmission
docker inspect transmission > /dev/null 2>&1
transmission_installed=$?

# 如果安装了qbittorrent，将qbittorrent的目录挂载到iyuu容器内
if [ $qbittorrent_installed -eq 0 ]; then
    qbittorrent_dir="-v ${base_data_dir}/qbittorrent:/qbittorrent"
else 
    qbittorrent_dir=""
fi
# 如果安装了transmission，将transmission的目录挂载到iyuu容器内
if [ $transmission_installed -eq 0 ]; then
    transmission_dir="-v ${base_data_dir}/transmission:/transmission"
else 
    transmission_dir=""
fi

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-m 256M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v ${base_data_dir}/public/downloads:/data/downloads \
-v ${base_data_dir}/${container_name}/data:/data \
-v ${base_data_dir}/${container_name}/iyuu:/iyuu \
${qbittorrent_dir} \
${transmission_dir} \
--network=$docker_network_name --network-alias=${container_name} \
--hostname=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}

