#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

set -e

container_name=radicale
port=5232
image=ghcr.io/kozea/radicale:stable
utils_image=ghcr.io/dezhishen/apache-utils:3.20-alpine


mkdir -p ${base_data_dir}/${container_name}/data
mkdir -p ${base_data_dir}/${container_name}/config
read -p "是否创建用户和密码[y/n]:" create_user_and_password
case $create_user_and_password in
    [Yy]* )
        touch ${base_data_dir}/${container_name}/users
        radicale_user=$(`dirname $0`/get-args.sh RADICALE_USER 用户名)
        if [ -z "$radicale_user" ]; then
            read -p "请输入用户名:" radicale_user
            if [ -z "$radicale_user" ]; then
                echo "用户名使用默认值: admin"
                radicale_user="admin"
            fi
            `dirname $0`/set-args.sh RADICALE_USER "$radicale_user"
        fi
        radicale_password=$(`dirname $0`/get-args.sh RADICALE_PASSWORD 密码)
        if [ -z "$radicale_password" ]; then
            read -p "请输入密码:" radicale_password
            if [ -z "$radicale_password" ]; then
                echo "随机生成密码"
                radicale_password=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
            fi
            `dirname $0`/set-args.sh RADICALE_PASSWORD "$radicale_password"
        fi
        # 使用自建 apache-utils 镜像生成 htpasswd（-cb：创建文件 + 非交互写入密码）
        docker run --rm --user=`id -u`:`id -g` \
            -e RAD_USER="$radicale_user" \
            -e RAD_PASS="$radicale_password" \
            -v ${base_data_dir}/${container_name}/users:/etc/users \
            ${utils_image} \
            sh -c 'htpasswd -cb /etc/users "$RAD_USER" "$RAD_PASS"'
        echo "用户名: $radicale_user"
        echo "密码: $radicale_password"
    ;;
    [Nn]* )
        echo "不创建用户和密码"
    ;;
esac

# 检查配置文件是否存在
if [ ! -f ${base_data_dir}/${container_name}/config/config ]; then
    echo "配置文件不存在，创建配置文件"
    touch ${base_data_dir}/${container_name}/config/config
fi
# 检查配置文件的内容是否包含 
# [auth]
# type = htpasswd
# htpasswd_filename = /path/to/users
# encryption method used in the htpasswd file
# htpasswd_encryption = autodetect

has_auth_config=false
if cat ${base_data_dir}/${container_name}/config/config | grep -q "\[auth\]"; then
    has_auth_config=true
fi
if [ $has_auth_config = false ]; then
    echo "配置文件中没有[auth]配置，添加[auth]配置"
    echo "[auth]" >> ${base_data_dir}/${container_name}/config/config
    echo "type = htpasswd" >> ${base_data_dir}/${container_name}/config/config
    echo "htpasswd_filename = /etc/users" >> ${base_data_dir}/${container_name}/config/config
    echo "htpasswd_encryption = plain" >> ${base_data_dir}/${container_name}/config/config
fi

docker pull $image
`dirname $0`/stop-container.sh ${container_name}

docker run --restart=always -d --name ${container_name} \
    -m 128M \
    --user=`id -u`:`id -g` \
    -v ${base_data_dir}/${container_name}/data:/var/lib/radicale \
    -v ${base_data_dir}/${container_name}/config:/etc/radicale \
    -v ${base_data_dir}/${container_name}/users:/etc/users \
    --network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name} \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
    --label "traefik.enable=true" \
${image}