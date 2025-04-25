#! /bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

container_name=vaultwarden
image=vaultwarden/server:latest
port=80

`dirname $0`/create-dir.sh $base_data_dir/${container_name}
`dirname $0`/create-dir.sh $base_data_dir/${container_name}/data


database_url=""
database_env_str=""

VAULTWARDEN_DATABASE_TYPE=$(`dirname $0`/get-args.sh VAULTWARDEN_DATABASE_TYPE 数据库类型[sqlite3/mysql/postgresql])
if [ -z "$VAULTWARDEN_DATABASE_TYPE" ]; then
    echo "使用默认值: sqlite3"
    VAULTWARDEN_DATABASE_TYPE=sqlite3
    `dirname $0`/set-args.sh VAULTWARDEN_DATABASE_TYPE "$VAULTWARDEN_DATABASE_TYPE"
fi
# 判断输入是否正确
case $MOVIEPILOT_AUTH_SITE in
    sqlite3)
        echo "使用输入值: $VAULTWARDEN_DATABASE_TYPE"
        `dirname $0`/set-args.sh VAULTWARDEN_DATABASE_TYPE "$VAULTWARDEN_DATABASE_TYPE"
        # 是否关闭 WAL
        VAULTWARDEN_DATABASE_WAL=$(`dirname $0`/get-args.sh VAULTWARDEN_DATABASE_WAL 是否关闭WAL)
        if [ -z "$VAULTWARDEN_DATABASE_WAL" ]; then
            read -p "是否关闭WAL(默认不关闭):" VAULTWARDEN_DATABASE_WAL
            if [ -z "$VAULTWARDEN_DATABASE_WAL" ]; then
                echo "使用默认值: false"
                VAULTWARDEN_DATABASE_WAL=false
            fi
        `dirname $0`/set-args.sh VAULTWARDEN_DATABASE_WAL "$VAULTWARDEN_DATABASE_WAL"
        fi
        database_env_str=" -e ENABLE_DB_WAL=$VAULTWARDEN_DATABASE_WAL"
        ;;
    mysql)
        echo "使用输入值: $VAULTWARDEN_DATABASE_TYPE"
        `dirname $0`/set-args.sh VAULTWARDEN_DATABASE_TYPE "$VAULTWARDEN_DATABASE_TYPE"
        MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST "mysql主机" )
        if [ -z "$MYSQL_HOST" ]; then
            read -p "请输入mysql主机:" MYSQL_HOST
            if [ -z "$MYSQL_HOST" ]; then
                echo "mysql主机为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_HOST "$MYSQL_HOST"
        fi
        MYSQL_PORT=$(`dirname $0`/get-args.sh MYSQL_PORT "mysql端口" )
        if [ -z "$MYSQL_PORT" ]; then
            read -p "请输入mysql端口:" MYSQL_PORT
            if [ -z "$MYSQL_PORT" ]; then
                echo "mysql端口为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_PORT "$MYSQL_PORT"
        fi
        MYSQL_USER=$(`dirname $0`/get-args.sh MYSQL_USER "mysql用户名" )
        if [ -z "$MYSQL_USER" ]; then
            read -p "请输入mysql用户名:" MYSQL_USER
            if [ -z "$MYSQL_USER" ]; then
                echo "mysql用户名为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_USER "$MYSQL_USER"
        fi
        MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "mysql密码" )
        if [ -z "$MYSQL_PASSWORD" ]; then
            read -p "请输入mysql密码:" MYSQL_PASSWORD
            if [ -z "$MYSQL_PASSWORD" ]; then
                echo "mysql密码为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_PASSWORD "$MYSQL_PASSWORD"
        fi
        MYSQL_DB_NAME=vaultwarden
        if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_DB_NAME" ] || [ -z "$MYSQL_USER" ]; then
            echo "未输入mysql主机、密码、数据库名或用户名，退出安装。"
            exit 1
        fi
        database_url="mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST:$MYSQL_PORT/$MYSQL_DB_NAME"
        database_env_str=" -e DATABASE_URL=$database_url"
        ;;
    postgresql)
        echo "本脚本暂不支持postgresql"
        exit 1
        ;;
    *)
        echo "输入错误"
        exit 1
        ;;
esac


docker pull ${image}


`dirname $0`/stop-container.sh ${container_name}

docker run -d --name ${container_name} \
--restart=always \
-e TZ="Asia/Shanghai" \
-e SIGNUPS_ALLOWED="true" \
-m 256M \
-e LANG="zh_CN.UTF-8" \
${database_env_str} \
-u $(id -u):$(id -g) \
--network=$docker_network_name --network-alias=${container_name} \
-v $base_data_dir/vaultwarden/data:/data/  \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
${image}