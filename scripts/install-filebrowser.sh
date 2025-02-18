#! /bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=filebrowser
image=filebrowser/filebrowser

`dirname $0`/create-dir.sh $base_data_dir/filebrowser

docker pull $image

if [ ! -f $base_data_dir/${container_name}/database.db ];then
    echo "filebrowser.db 不存在，创建 $base_data_dir/${container_name}/database.db"
    touch $base_data_dir/${container_name}/database.db 
else
    echo "filebrowser.db 已存在，不需要创建"
fi
if [ ! -f $base_data_dir/${container_name}/filebrowser.json ];then
    echo "filebrowser.json 不存在，创建 $base_data_dir/${container_name}/filebrowser.json"
    echo '{"port": 8080,"baseURL": "","address": "","log": "stdout","database": "/database.db","root": "/srv" }' \
    > $base_data_dir/${container_name}/filebrowser.json
else
    echo "filebrowser.json 已存在，不需要创建,filebrowser.json already exist"
fi

`dirname $0`/stop-container.sh ${container_name}
docker run \
    -d --restart=always --hostname=${container_name} --name=${container_name} \
    --health-cmd "curl -f http://localhost:8080/health || exit 1" \
    -m 256M --memory-swap=1024M \
    --network=$docker_network_name --network-alias=${container_name} \
    -u $(id -u):$(id -g) \
    -v $base_data_dir:/srv \
    -v "$base_data_dir/${container_name}/database.db:/database.db" \
    -v "$base_data_dir/${container_name}/filebrowser.json:/.filebrowser.json" \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=8080" \
    --label "traefik.enable=true" \
$image
