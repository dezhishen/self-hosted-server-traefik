# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
image=linuxserver/transmission
port=9091
container_name=transmission
docker pull ${image}

TRANSMISSION_USER=$(`dirname $0`/get-args.sh TRANSMISSION_USER 用户名)
if [ -z "$TRANSMISSION_USER" ]; then
    read -p "请输入用户名:" TRANSMISSION_USER
    if [ -z "$TRANSMISSION_USER" ]; then
        echo "用户名使用默认值: admin"
        TRANSMISSION_USER="admin"
    fi
    `dirname $0`/set-args.sh TRANSMISSION_USER "$TRANSMISSION_USER"
fi

TRANSMISSION_PASSWORD=$(`dirname $0`/get-args.sh TRANSMISSION_PASSWORD 密码)
if [ -z "$TRANSMISSION_PASSWORD" ]; then
    read -p "请输入密码:" TRANSMISSION_PASSWORD
    if [ -z "$TRANSMISSION_PASSWORD" ]; then
        echo "随机生成密码"
        TRANSMISSION_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh TRANSMISSION_PASSWORD "$TRANSMISSION_PASSWORD"
fi

`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
--restart=always \
-m 512M \
--network=host \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-e USER=${TRANSMISSION_USER} \
-e PASS=${TRANSMISSION_PASSWORD} \
-v $base_data_dir/${container_name}/config:/config \
-v $base_data_dir/public/downloads:/data/downloads \
-v $base_data_dir/${container_name}/incomplete-torrents:/incomplete-torrents \
-v $base_data_dir/${container_name}/finished-torrents:/finished-torrents \
${image}
`dirname $0`/create-traefik-provider.sh $domain $base_data_dir $docker_network_name $tls $container_name $port