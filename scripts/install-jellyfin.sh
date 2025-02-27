# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=jellyfin
image=linuxserver/jellyfin:latest
port=8096
# 是否重装jellyfin
read -p "是否重装jellyfin? [y/n] " reinstall
if [ "$reinstall" = "y" ]; then

    docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}
    video_gid=$(cat /etc/group | grep -e video | cut -d ":" -f 3)
    render_gid=$(cat /etc/group | grep -e render | cut -d ":" -f 3)
    docker run  \
    --hostname ${container_name} \
    --privileged --restart=always -d \
    --device /dev/dri \
    -e PUID=`id -u` -e PGID=`id -g` \
    --name=${container_name} \
    -m 1024M \
    --network=$docker_network_name \
    --network-alias=${container_name} \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    -v $base_data_dir/jellyfin/config:/config \
    -v $base_data_dir/public/:/data \
    -p ${port}:${port} \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
    --label "traefik.enable=true" \
    ${image}
fi
# 是否安装jellysearch
read -p "是否安装jellysearch? [y/n] " install_jellysearch
if [ "$install_jellysearch" = "y" ]; then
    MEILI_MASTER_KEY=$(`dirname $0`/get-args.sh MEILI_MASTER_KEY MasterKey)
    if [ -z "$MEILI_MASTER_KEY" ]; then
        read -p "请输入MasterKey:" MEILI_MASTER_KEY
        if [ -z "$MEILI_MASTER_KEY" ]; then
            echo "随机生成MasterKey"
            MEILI_MASTER_KEY="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
            echo "随机MasterKey为：${MEILI_MASTER_KEY}"
        fi
        `dirname $0`/set-args.sh MEILI_MASTER_KEY "$MEILI_MASTER_KEY"
    fi

    jellyfin_container_name=${container_name}
    container_name=jellysearch
    image=domistyle/jellysearch
    port=5000
    docker run --restart=always -d -m 128M \
    --hostname ${container_name} --network=$docker_network_name --network-alias=${container_name} \
    -e PUID=`id -u` -e PGID=`id -g` \
    -e MEILI_MASTER_KEY=${MEILI_MASTER_KEY} \
    -e INDEX_CRON="0 0 0/2 ? * * *" \
    --user=`id -u`:`id -g` \
    --name=${container_name} \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    -v $base_data_dir/jellyfin/config:/config \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${jellyfin_container_name}.$domain'`) && ( QueryRegexp(`searchTerm`, `(.*?)`) || QueryRegexp(`SearchTerm`, `(.*?)`))' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
    --label "traefik.enable=true" \
    ${image}
fi