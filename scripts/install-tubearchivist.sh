#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=tubearchivist
image=bbilly1/tubearchivist
port=8000


ZINCSEARCH_HOST=$(`dirname $0`/get-args.sh ZINCSEARCH_HOST ZINCSEARCH地址)
if [ -z "$ZINCSEARCH_HOST" ]; then
    echo "zincsearch 地址为空，检测是否安装了 zincsearch"
    exit
fi

ZINCSEARCH_PORT=$(`dirname $0`/get-args.sh ZINCSEARCH_PORT ZINCSEARCH端口)
if [ -z "$ZINCSEARCH_PORT" ]; then
    echo "zincsearch 端口为空，检测是否安装了 zincsearch"
    exit 1
fi

ZINCSEARCH_AUTH_USER=$(`dirname $0`/get-args.sh ZINCSEARCH_AUTH_USER ZINCSEARCH用户名)
if [ -z "$ZINCSEARCH_AUTH_USER" ]; then
    echo "必须输入ZINCSEARCH的用户名"
    exit 1
fi

ZINCSEARCH_AUTH_PASSWORD=$(`dirname $0`/get-args.sh ZINCSEARCH_AUTH_PASSWORD ZINCSEARCH密码)
if [ -z "$ZINCSEARCH_AUTH_PASSWORD" ]; then
    echo "必须输入ZINCSEARCH密码"
    exit 1
fi
REDIS_HOST=$(`dirname $0`/get-args.sh REDIS_HOST redis的地址)
if [ -z "$REDIS_HOST" ]; then
    echo "redis地址为空，检测是否安装了redis"
    exit 1
fi
REDIS_CON=""
REDIS_PASSWORD_SET=$(`dirname $0`/get-args.sh REDIS_PASSWORD_SET redis是否设置了密码[y/n])
if [ $REDIS_PASSWORD_SET = "y" ]; then
    REDIS_PASSWORD=$(`dirname $0`/get-args.sh REDIS_PASSWORD redis密码)
    if [ -z "$REDIS_PASSWORD" ]; then
            echo "必须输入redis的密码"
            exit 1
    else
        REDIS_CON="redis://:${REDIS_PASSWORD}@${REDIS_HOST}:6379"
    fi
else
    REDIS_CON="redis://${REDIS_HOST}:6379"
fi

if [ "$tls" = "true " ]; then
    TA_HOST=https://${container_name}.$domain
else
    TA_HOST=http://${container_name}.$domain
fi
TUBEARCHIVIST_AUTH_USER=$(`dirname $0`/get-args.sh TUBEARCHIVIST_AUTH_USER 用户名)
if [ -z "$TUBEARCHIVIST_AUTH_USER" ]; then
    read -p "请输入用户名:" TUBEARCHIVIST_AUTH_USER
    if [ -z "$TUBEARCHIVIST_AUTH_USER" ]; then
        echo "用户名使用默认值: admin"
        TUBEARCHIVIST_AUTH_USER="admin"
    fi
    `dirname $0`/set-args.sh TUBEARCHIVIST_AUTH_USER "$TUBEARCHIVIST_AUTH_USER"
fi

TUBEARCHIVIST_AUTH_PASSWORD=$(`dirname $0`/get-args.sh TUBEARCHIVIST_AUTH_PASSWORD 密码)
if [ -z "$TUBEARCHIVIST_AUTH_PASSWORD" ]; then
    read -p "请输入密码:" TUBEARCHIVIST_AUTH_PASSWORD
    if [ -z "$TUBEARCHIVIST_AUTH_PASSWORD" ]; then
        echo "随机生成密码"
        TUBEARCHIVIST_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh TUBEARCHIVIST_AUTH_PASSWORD "$TUBEARCHIVIST_AUTH_PASSWORD"
fi

docker pull ${image}

`dirname $0`/stop-container.sh ${container_name}

docker run -d --restart=always \
--name=${container_name} \
--network=$docker_network_name \
--network-alias=${container_name} \
--hostname=${container_name} \
--health-cmd "curl -f http://localhost:${TA_PORT}/api/health || exit 1" \
--health-start-period=30s \
--health-start-interval=2m \
--health-retries=3 \
--health-timeout=10s \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e REDIS_CON=${REDIS_CON} \
-e HOST_UID=`id -u` \
-e HOST_GID=`id -g` \
-e TA_HOST=${TA_HOST} \
-e TA_PORT=${port} \
-e TA_USERNAME=${TUBEARCHIVIST_AUTH_USER} \
-e TA_PASSWORD=${TUBEARCHIVIST_AUTH_PASSWORD} \
-e ES_URL=http://${ZINCSEARCH_HOST}:${ZINCSEARCH_PORT} \
-e ELASTIC_USER=${ZINCSEARCH_AUTH_USER} \
-e ELASTIC_PASSWORD=${ZINCSEARCH_AUTH_PASSWORD} \
-v ${base_data_dir}/${container_name}/youtube:/youtube \
-v ${base_data_dir}/${container_name}/cache:/cache \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}