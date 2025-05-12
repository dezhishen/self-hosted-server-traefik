#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
set -e
pre=immich
port=8080

IMMICH_DATA_PASSWORD=$(`dirname $0`/get-args.sh IMMICH_DATA_PASSWORD 数据库密码)
if [ -z "$IMMICH_DATA_PASSWORD" ]; then
    read -p "请输入数据库密码:" IMMICH_DATA_PASSWORD
    if [ -z "$IMMICH_DATA_PASSWORD" ]; then
        echo "随机生成密码"
        IMMICH_DATA_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh IMMICH_DATA_PASSWORD "$IMMICH_DATA_PASSWORD"
fi

app=database
read -p "是否重装${app} (y/n)" yN
case $yN in
    [Yy]* )
    # 如果文件夹不存在，则创建文件夹
    if [ ! -d ${base_data_dir}/${pre}/database ]; then
        mkdir -p ${base_data_dir}/${pre}/database
    fi
    container_name=${pre}-${app}
    image=tensorchord/pgvecto-rs:pg14-v0.2.0
    docker pull $image
    `dirname $0`/stop-container.sh ${container_name}
    docker run --name=${container_name} \
    --hostname=${container_name} \
    -m 256M \
    --user=`id -u`:`id -g` \
    -d --restart=always \
    -e TZ=Asia/Shanghai \
    -e LANG="C.UTF-8" \
    -e POSTGRES_PASSWORD=${IMMICH_DATA_PASSWORD} \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_DB=immich \
    --network=$docker_network_name --network-alias=${container_name} \
    -v ${base_data_dir}/${pre}/database:/var/lib/postgresql/data \
    $image
    ;;
esac


app=server
read -p "是否重装${app} (y/n)" yN
case $yN in
    [Yy]* )
    # 获取redis信息
    REDIS_HOST=$(`dirname $0`/get-args.sh REDIS_HOST "redis的host")
    if [ -z "$REDIS_HOST" ]; then
        read -p "请输入redis的host:" REDIS_HOST
        if [ -z "$REDIS_HOST" ]; then
            echo "未输入redis的host，将退出"
            exit 1
        fi
    fi
    REDIS_PORT=$(`dirname $0`/get-args.sh REDIS_PORT "redis的port")
    if [ -z "$REDIS_PORT" ]; then
        read -p "请输入redis的port:" REDIS_PORT
        if [ -z "$REDIS_PORT" ]; then
            echo "未输入redis的port，将使用默认值6379"
            REDIS_PORT=6379
        fi
    fi
    REDIS_PASSWORD_SET=$(`dirname $0`/get-args.sh REDIS_PASSWORD_SET "是否设置了Redis密码")
    if [ $REDIS_PASSWORD_SET = "y" ]; then 
        REDIS_PASSWORD=$(`dirname $0`/get-args.sh REDIS_PASSWORD "Redis密码")
    fi
    IMMICH_REDIS_DBINDEX=$(`dirname $0`/get-args.sh IMMICH_REDIS_DBINDEX "请输入immich使用的redis db")
    if [ -z "$IMMICH_REDIS_DBINDEX" ]; then
        read -p "请输入immich使用的redis db:" IMMICH_REDIS_DBINDEX
        if [ -z "$IMMICH_REDIS_DBINDEX" ]; then
            echo "未输入redis的db，将使用默认值0"
            IMMICH_REDIS_DBINDEX=6379
        fi
        `dirname $0`/set-args.sh IMMICH_REDIS_DBINDEX ${IMMICH_REDIS_DBINDEX}
    fi
    container_name=${pre}-${app}
    image=ghcr.io/imagegenius/immich:latest
    docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}
    docker run --name=${container_name} \
    --hostname=${container_name} \
    --privileged -d --restart=always \
    -m 1G \
    -e PUID=`id -u` -e GUID=`id -g` \
    -e TZ="Asia/Shanghai" \
    -e LANG="C.UTF-8" \
    -e DB_HOSTNAME=${pre}-database \
    -e DB_USERNAME=postgres \
    -e DB_PASSWORD=${IMMICH_DATA_PASSWORD} \
    -e DB_DATABASE_NAME=immich \
    -e DB_PORT=5432 \
    -e REDIS_HOSTNAME=redis \
    -e REDIS_PORT=6379 \
    -e REDIS_PASSWORD=${REDIS_PASSWORD} \
    -e REDIS_DBINDEX=${IMMICH_REDIS_DBINDEX} \
    --network=$docker_network_name --network-alias=${container_name} \
    -v ${base_data_dir}/${pre}/config:/config \
    -v ${base_data_dir}/public/photos:/photos/library \
    -v ${base_data_dir}/${pre}/photos/encoded-video:/photos/encoded-video \
    -v ${base_data_dir}/${pre}/photos/thumbs:/photos/thumbs \
    -v ${base_data_dir}/${pre}/photos/upload:/photos/upload \
    -v ${base_data_dir}/${pre}/photos/profile:/photos/profile \
    -v ${base_data_dir}/${pre}/photos/backups:/photos/backups \
    --device /dev/dri:/dev/dri \
    --device-cgroup-rule='c 189:* rmw' \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.${pre}.service=${pre}" \
    --label 'traefik.http.routers.'${pre}'.rule=Host(`'${pre}''.$domain'`)' \
    --label "traefik.http.routers.${pre}.tls=${tls}" \
    --label "traefik.http.routers.${pre}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${pre}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${pre}.loadbalancer.server.port=${port}" \
    $image
    ;;
esac
