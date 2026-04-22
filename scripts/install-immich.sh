#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
set -e
pre=immich
port=2283
old_version=$(`dirname $0`/get-args-nochange.sh IMMICH_VERSION immich的版本)
video_gid=$(cat /etc/group | grep -e video | cut -d ":" -f 3)
render_gid=$(cat /etc/group | grep -e render | cut -d ":" -f 3)
IMMICH_VERSION=$(`dirname $0`/get-args.sh IMMICH_VERSION immich的版本)
if [ -z "$IMMICH_VERSION" ]; then
    read -p "请输入immich的版本:" IMMICH_VERSION
    if [ -z "$IMMICH_VERSION" ]; then
        echo "使用最新版本"
	IMMICH_VERSION="latest"
    fi
    `dirname $0`/set-args.sh IMMICH_VERSION ${IMMICH_VERSION}
fi

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
    image=ghcr.nju.edu.cn/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0 
    #tensorchord/pgvecto-rs:pg14-v0.2.0
    #docker pull $image
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
    -v ${base_data_dir}/${pre}/${version}/database:/var/lib/postgresql/data \
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
    image=ghcr.nju.edu.cn/immich-app/immich-server:${IMMICH_VERSION}
    echo "开始创建数据目录（如果目录不存在）...."
    mkdir -p ${base_data_dir}/public/photos/library
    mkdir -p ${base_data_dir}/${pre}/data/encoded-video
    mkdir -p ${base_data_dir}/${pre}/data/thumbs
    mkdir -p ${base_data_dir}/${pre}/data/upload
    mkdir -p ${base_data_dir}/${pre}/data/profile
    mkdir -p ${base_data_dir}/${pre}/data/backups
    `dirname $0`/stop-container.sh ${container_name}
    # 如果新版本和老版本不一样，则备份老版本数据
    if [ "$IMMICH_VERSION" != "$old_version" ]; then
        read -p "检测到immich版本发生变化，是否备份老版本数据？(y/n)" backupYN
        case $backupYN in
            [Yy]* )
                bakcup_dir=${base_data_dir}/${pre}/old-version-backup/
                filename=${old_version}-$(date +%Y%m%d%H%M%S)
                mkdir -p ${bakcup_dir}
                # 检验 tar 命令是否可用，如果可用则使用tar命令进行备份，否则使用cp命令进行备份
                if command -v tar &> /dev/null; then
                    echo "开始备份老版本数据 到${bakcup_dir}/${filename}.tar.gz,请耐心等待..."
                    tar -zcf ${bakcup_dir}/${filename}.tar.gz -C ${base_data_dir}/${pre}/data .
                    echo "备份完成，开始创建新版本容器...."
                else
                    echo "tar命令不可用，使用cp命令进行备份..."
                    echo "开始备份老版本数据 到${bakcup_dir}/${filename},请耐心等待..."
                    cp -r ${base_data_dir}/${pre}/data ${bakcup_dir}/${filename}
                    echo "备份完成，开始创建新版本容器...."
                fi
            ;;
            * )
                echo "不备份老版本数据，直接创建新版本容器..."
            ;;
        esac
    fi
    docker pull ${image}
    docker run --name=${container_name} \
    --hostname=${container_name} \
    --user $(id -u):$(id -g) \
    --group-add "${video_gid}" --group-add "${render_gid}" \
    -d --restart=always \
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
    --device /dev/dri:/dev/dri \
    -v ${base_data_dir}/public/photos/library:/data/library \
    -v ${base_data_dir}/${pre}/data/encoded-video:/data/encoded-video \
    -v ${base_data_dir}/${pre}/data/thumbs:/data/thumbs \
    -v ${base_data_dir}/${pre}/data/upload:/data/upload \
    -v ${base_data_dir}/${pre}/data/profile:/data/profile \
    -v ${base_data_dir}/${pre}/data/backups:/data/backups \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.${pre}.service=${pre}" \
    --label 'traefik.http.routers.'${pre}'.rule=Host(`'${pre}''.$domain'`)' \
    --label "traefik.http.routers.${pre}.tls=${tls}" \
    --label "traefik.http.routers.${pre}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${pre}.tls.domains[0].main=${pre}.$domain" \
    --label "traefik.http.services.${pre}.loadbalancer.server.port=${port}" \
    $image
    ;;
esac

app=maching-learning
read -p "是否重装${app} (y/n)" yN
case $yN in
    [Yy]* )
    container_name=${pre}-${app}
    image=ghcr.nju.edu.cn/immich-app/immich-machine-learning:${IMMICH_VERSION}-openvino
    mkdir -p ${base_data_dir}/${pre}/machine-learning/cache
    mkdir -p ${base_data_dir}/${pre}/machine-learning/.config
    mkdir -p ${base_data_dir}/${pre}/machine-learning/.cache
    mkdir -p ${base_data_dir}/${pre}/machine-learning/.local
    docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}
    docker run --name=${container_name} \
    --hostname=${container_name} \
    -d --restart=always \
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
    --device /dev/dri:/dev/dri \
    --group-add "${video_gid}" --group-add "${render_gid}" \
    --user $(id -u):$(id -g) \
    --device-cgroup-rule='c 189:* rmw' \
    -v /dev/bus/usb:/dev/bus/usb \
    -v ${base_data_dir}/${pre}/machine-learning/cache:/cache \
    -v ${base_data_dir}/${pre}/machine-learning/.config:/.config \
    -v ${base_data_dir}/${pre}/machine-learning/.cache:/.cache \
    -v ${base_data_dir}/${pre}/machine-learning/.local:/.local \
    $image
    ;;
esac
