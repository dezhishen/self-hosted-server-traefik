#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=fava
image=yegle/fava
port=5000

docker pull $image
`dirname $0`/stop-container.sh ${container_name}
# 如果不存在main.bean，则创建
if [ ! -f ${base_data_dir}/${container_name}/bean/main.bean ]; then
    touch ${base_data_dir}/${container_name}/bean/main.bean
    mkdir -p ${base_data_dir}/${container_name}/bean/accounts
    echo "include ./accounts/*.bean" > ${base_data_dir}/${container_name}/bean/main.bean
    mkdir -p ${base_data_dir}/${container_name}/bean/includes
    echo "include ./includes/*.bean" >> ${base_data_dir}/${container_name}/bean/main.bean
fi
docker run --restart=always -d --name ${container_name} -m 512M \
--user=`id -u`:`id -g` \
-e TZ=Asia/Shanghai \
-e LANG=zh_CN.UTF-8 \
-e BEANCOUNT_FILE=/bean/main.bean \
-v ${base_data_dir}/${container_name}/bean:/bean:Z \
--network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name} \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image} 