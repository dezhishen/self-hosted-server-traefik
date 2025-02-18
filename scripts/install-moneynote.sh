#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4


container_name=moneynode-api
port=9092
image=registry.cn-hangzhou.aliyuncs.com/moneynote/moneynote-api:latest
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
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
invite_code=$(`dirname $0`/get-args.sh money_node_invite_code "邀请码" )
docker run --name=${container_name} \
-d --restart=always \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e DB_HOST=${MYSQL_HOST} \
-e DB_PORT=${MYSQL_PORT:-3306} \
-e DB_NAME=moneynote \
-e DB_USER=${MYSQL_USER} \
-e DB_PASSWORD=${MYSQL_PASSWORD} \
-e invite_code=${invite_code:-111111} \
--network=$docker_network_name --network-alias=${container_name} \
--hostname=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}

container_name=moneynode-pc
port=80
image=registry.cn-hangzhou.aliyuncs.com/moneynote/moneynote-pc:latest
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
-d --restart=always \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e USER_API_HOST=http://moneynode-api:9092 \
--network=$docker_network_name --network-alias=${container_name} \
--hostname=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}


container_name=moneynode-h5
port=80
image=registry.cn-hangzhou.aliyuncs.com/moneynote/moneynote-h5:latest
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
-d --restart=always \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e USER_API_HOST=http://moneynode-api:9092 \
--network=$docker_network_name --network-alias=${container_name} \
--hostname=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
${image}
