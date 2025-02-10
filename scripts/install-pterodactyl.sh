#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=pterodactyl

MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST "mysql主机" )
MYSQL_PORT=$(`dirname $0`/get-args.sh MYSQL_PORT "mysql主机端口" )
MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "mysql密码" )
MYSQL_USER=$(`dirname $0`/get-args.sh MYSQL_USER "mysql用户名" )
if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_USER" ]; then
    echo "MYSQL_HOST: $MYSQL_HOST"
    echo "MYSQL_PASSWORD: $MYSQL_PASSWORD"
    echo "MYSQL_USER: $MYSQL_USER"
    echo "未输入mysql主机、密码、数据库名或用户名，退出安装。"
    exit 1
fi

REDIS_HOST="redis"
app=panel
image=pterodactylchina/panel
port=80
mkdir -p ${base_data_dir}/${container_name}
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}-${app}
docker run --name=${container_name}-${app} \
-m 256M \
-d --restart=always \
-e PUID=`id -u` -e PGID=`id -g` \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e DB_PASSWORD=${MYSQL_PASSWORD} \
-e APP_ENV="production" \
-e APP_ENVIRONMENT_ONLY="false" \
-e CACHE_DRIVER="redis" \
-e SESSION_DRIVER="redis" \
-e QUEUE_DRIVER="redis" \
-e REDIS_HOST=${REDIS_HOST} \
-e DB_USERNAME=${MYSQL_USER} \
-e DB_HOST=${MYSQL_HOST} \
-e DB_PORT=${MYSQL_PORT} \
--network=$docker_network_name --network-alias=${container_name}-${app} --hostname=${container_name}-${app}  \
-v /etc/localtime:/etc/localtime:ro \
-v ${base_data_dir}/${container_name}/${app}/var:/app/var \
-v ${base_data_dir}/${container_name}/${app}/nginx:/etc/nginx/http.d \
-v ${base_data_dir}/${container_name}/${app}/certs:/etc/letsencrypt \
-v ${base_data_dir}/${container_name}/${app}/logs:/app/storage/logs \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}-${app}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}-${app}.tls=${tls}" \
--label "traefik.http.routers.${container_name}-${app}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}-${app}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}-${app}.loadbalancer.server.port=${port}" \
${image}