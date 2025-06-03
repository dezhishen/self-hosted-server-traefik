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

FAVA_AUTH_USER=$(`dirname $0`/get-args.sh FAVA_AUTH_USER 用户名)
if [ -z "$FAVA_AUTH_USER" ]; then
    read -p "请输入用户名:" FAVA_AUTH_USER
    if [ -z "$FAVA_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        FAVA_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh FAVA_AUTH_USER "$FAVA_AUTH_USER"
fi

FAVA_AUTH_PASSWORD=$(`dirname $0`/get-args.sh FAVA_AUTH_PASSWORD 密码)
if [ -z "$FAVA_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" FAVA_AUTH_PASSWORD
    if [ -z "$FAVA_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        FAVA_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh FAVA_AUTH_PASSWORD "$FAVA_AUTH_PASSWORD"
fi

echo "用户名: $FAVA_AUTH_USER"
echo "密码: $FAVA_AUTH_PASSWORD"
digest="$(printf "%s:%s:%s" "$FAVA_AUTH_USER" "traefik" "$FAVA_AUTH_PASSWORD" | md5sum | awk '{print $1}' )"
userlist=$(printf "%s:%s:%s\n" "$FAVA_AUTH_USER" "traefik" "$digest")
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
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.http.middlewares.${container_name}-auth.digestauth.users=$userlist" \
--label "traefik.http.routers.${container_name}.middlewares=${container_name}-auth@docker" \
--label "traefik.enable=true" \
${image} 