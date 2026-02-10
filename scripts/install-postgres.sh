#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=postgres
version=15
image=postgres:${version}
port=5432
POSTGRES_PASSWORD=$(`dirname $0`/get-args.sh POSTGRES_PASSWORD 密码)
if [ -z "$POSTGRES_PASSWORD" ]; then
    read -p "请输入密码:" POSTGRES_PASSWORD
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo "随机生成密码"
        POSTGRES_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh POSTGRES_PASSWORD "$POSTGRES_PASSWORD"
fi
read -p "是否重装 postgres ? [y/n] " install_postgres
if [ "$install_postgres" = "y" ]; then
    mkdir -p ${base_data_dir}/${container_name}/${version}/data
    chown -R 999:999 ${base_data_dir}/${container_name}/${version}/data
    POSTGRES_PORT_MAPPING=$(`dirname $0`/get-args.sh POSTGRES_PORT_MAPPING 是否映射端口[y/n])
    if [ -z "$POSTGRES_PORT_MAPPING" ]; then
        read -p "是否映射端口[y/n]:" POSTGRES_PORT_MAPPING
        if [ -z "$POSTGRES_PORT_MAPPING" ]; then
            echo "是否映射端口[y/n]为空，默认不映射端口"
            POSTGRES_PORT_MAPPING="n"
        fi
        `dirname $0`/set-args.sh POSTGRES_PORT_MAPPING "$POSTGRES_PORT_MAPPING"
    fi
    docker pull $image
    docker stop $container_name > /dev/null
    docker rm $container_name
    docker run --restart=always -d --name ${container_name} -m 512M \
    -e TZ=Asia/Shanghai \
    -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 \
    -e POSTGRES_USER=root \
    -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    `if [ $POSTGRES_PORT_MAPPING = "y" ]; then echo "-p ${port}:${port}"; fi` \
    -v ${base_data_dir}/${container_name}/${version}/data:/var/lib/postgresql/data:Z \
    --network=${docker_network_name} --network-alias=${container_name} \
    ${image}
    echo "设置 POSTGRES_HOST 为${container_name}"
    `dirname $0`/set-args.sh POSTGRES_HOST "${container_name}"
    echo "设置 POSTGRES_PORT 为${port}"
    `dirname $0`/set-args.sh POSTGRES_PORT "${port}"
fi
