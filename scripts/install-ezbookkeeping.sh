#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=ezbookkeeping
image=mayswind/ezbookkeeping
mkdir -p ${base_data_dir}/${container_name}/config 
mkdir -p ${base_data_dir}/${container_name}/data 
mkdir -p ${base_data_dir}/${container_name}/logs
# create config file if not exists
if [ ! -f ${base_data_dir}/${container_name}/config/ezbookkeeping.ini ]; then
    wget https://raw.githubusercontent.com/mayswind/ezbookkeeping/refs/heads/main/conf/ezbookkeeping.ini -O ${base_data_dir}/${container_name}/config/ezbookkeeping.ini
fi
EBK_VERSION=$(`dirname $0`/get-args.sh EBK_VERSION 版本)
if [ -z "$EBK_VERSION" ]; then
    read -p "请输入的版本:" EBK_VERSION
    if [ -z "$EBK_VERSION" ]; then
        echo "默认使用最新版本"
	    EBK_VERSION="latest"
    fi
    `dirname $0`/set-args.sh EBK_VERSION ${EBK_VERSION}
fi

EBK_DATABASE_TYPE=$(`dirname $0`/get-args.sh EBK_DATABASE_TYPE "数据库类型[ sqlite3 / mysql / postgres "])
if [ -z "$EBK_DATABASE_TYPE" ]; then
    read -p "请输入数据库类型[ sqlite / mysql / postgres ]:" EBK_DATABASE_TYPE
    if [ -z "$EBK_DATABASE_TYPE" ]; then
        echo "默认使用sqlite3"
        EBK_DATABASE_TYPE="sqlite3"
    fi
    `dirname $0`/set-args.sh EBK_DATABASE_TYPE ${EBK_DATABASE_TYPE}
fi
case $EBK_DATABASE_TYPE in
    sqlite3 )
        echo "使用sqlite3数据库，无需额外配置"
        ELK_DB_PATH="/config/ezbookkeeping.db"
        database_env_str="-e EBK_DATABASE_TYPE=${EBK_DATABASE_TYPE} \
        -e EBK_DATABASE_DB_PATH=${ELK_DB_PATH} "
    ;;
    mysql )
        echo "使用mysql数据库，请确保已安装mysql数据库服务"
        MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST mysql数据库主机地址)
        if [ -z "$MYSQL_HOST" ]; then
            read -p "请输入mysql数据库主机地址:" MYSQL_HOST
            if [ -z "$MYSQL_HOST" ]; then
                echo "mysql数据库主机地址不能为空"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_HOST ${MYSQL_HOST}
        fi
        MYSQL_PORT=$(`dirname $0`/get-args.sh MYSQL_PORT mysql数据库端口)
        if [ -z "$MYSQL_PORT" ]; then
            read -p "请输入mysql数据库端口:" MYSQL_PORT
            if [ -z "$MYSQL_PORT" ]; then
                echo "默认使用3306端口"
                MYSQL_PORT=3306
            fi
            `dirname $0`/set-args.sh MYSQL_PORT ${MYSQL_PORT}
        fi
        EBK_MYSQL_DATABASE=$(`dirname $0`/get-args.sh EBK_MYSQL_DATABASE mysql数据库名称)
        if [ -z "$EBK_MYSQL_DATABASE" ]; then
            read -p "请输入mysql数据库名称:" EBK_MYSQL_DATABASE
            if [ -z "$EBK_MYSQL_DATABASE" ]; then
                echo "默认使用ezbookkeeping数据库"
                EBK_MYSQL_DATABASE="ezbookkeeping"
            fi
            `dirname $0`/set-args.sh EBK_MYSQL_DATABASE ${EBK_MYSQL_DATABASE}
        fi
        EBK_MYSQL_USER=$(`dirname $0`/get-args.sh EBK_MYSQL_USER mysql数据库用户名)
        if [ -z "$EBK_MYSQL_USER" ]; then
            read -p "请输入mysql数据库用户名:" EBK_MYSQL_USER
            if [ -z "$EBK_MYSQL_USER" ]; then
                echo "默认使用ezbookkeeping用户"
                EBK_MYSQL_USER="ezbookkeeping"
            fi
            `dirname $0`/set-args.sh EBK_MYSQL_USER ${EBK_MYSQL_USER}
        fi
        EBK_MYSQL_PASSWORD=$(`dirname $0`/get-args.sh EBK_MYSQL_PASSWORD mysql数据库密码)
        if [ -z "$EBK_MYSQL_PASSWORD" ]; then
            read -p "请输入mysql数据库密码:" EBK_MYSQL_PASSWORD
            if [ -z "$EBK_MYSQL_PASSWORD" ]; then
                echo "mysql数据库密码不能为空"
                exit 1
            fi
            `dirname $0`/set-args.sh EBK_MYSQL_PASSWORD ${EBK_MYSQL_PASSWORD}
        fi
        database_env_str="-e EBK_DATABASE_TYPE=${EBK_DATABASE_TYPE} \
        -e EBK_DATABASE_HOST=${MYSQL_HOST}:${MYSQL_PORT} \
        -e EBK_DATABASE_NAME=${EBK_MYSQL_DATABASE} \
        -e EBK_DATABASE_USER=${EBK_MYSQL_USER} \
        -e EBK_DATABASE_PASSWD=${EBK_MYSQL_PASSWORD} "
    ;;
    postgres )
        # POSTGRES_HOST
        # POSTGRES_PORT
        # EBK_POSTGRES_DATABASE
        # EBK_POSTGRES_USER
        # EBK_POSTGRES_PASSWORD
        echo "使用POSTGRESQL数据库，请确保已安装postgres数据库服务"
        POSTGRES_HOST=$(`dirname $0`/get-args.sh POSTGRES_HOST postgres数据库主机地址)
        if [ -z "$POSTGRES_HOST" ]; then
            read -p "请输入postgres数据库主机地址:" POSTGRES_HOST
            if [ -z "$POSTGRES_HOST" ]; then
                echo "postgres数据库主机地址不能为空"
                exit 1
            fi
            `dirname $0`/set-args.sh POSTGRES_HOST ${POSTGRES_HOST}
        fi
        POSTGRES_PORT=$(`dirname $0`/get-args.sh POSTGRES_PORT postgres数据库端口)
        if [ -z "$POSTGRES_PORT" ]; then
            read -p "请输入postgres数据库端口:" POSTGRES_PORT
            if [ -z "$POSTGRES_PORT" ]; then
                echo "默认使用5432端口"
                POSTGRES_PORT=5432
            fi
            `dirname $0`/set-args.sh POSTGRES_PORT ${POSTGRES_PORT}
        fi
        EBK_POSTGRES_DATABASE=$(`dirname $0`/get-args.sh EBK_POSTGRES_DATABASE postgres数据库名称)
        if [ -z "$EBK_POSTGRES_DATABASE" ]; then
            read -p "请输入postgres数据库名称:" EBK_POSTGRES_DATABASE
            if [ -z "$EBK_POSTGRES_DATABASE" ]; then
                echo "默认使用ezbookkeeping数据库"
                EBK_POSTGRES_DATABASE="ezbookkeeping"
            fi
            `dirname $0`/set-args.sh EBK_POSTGRES_DATABASE ${EBK_POSTGRES_DATABASE}
        fi
        EBK_POSTGRES_USER=$(`dirname $0`/get-args.sh EBK_POSTGRES_USER postgres数据库用户名)
        if [ -z "$EBK_POSTGRES_USER" ]; then
            read -p "请输入postgres数据库用户名:" EBK_POSTGRES_USER
            if [ -z "$EBK_POSTGRES_USER" ]; then
                echo "默认使用ezbookkeeping用户"
                EBK_POSTGRES_USER="ezbookkeeping"
            fi
            `dirname $0`/set-args.sh EBK_POSTGRES_USER ${EBK_POSTGRES_USER}
        fi
        EBK_POSTGRES_PASSWORD=$(`dirname $0`/get-args.sh EBK_POSTGRES_PASSWORD postgres数据库密码)
        if [ -z "$EBK_POSTGRES_PASSWORD" ]; then
            read -p "请输入postgres数据库密码:" EBK_POSTGRES_PASSWORD
            if [ -z "$EBK_POSTGRES_PASSWORD" ]; then
                echo "postgres数据库密码不能为空"
                exit 1
            fi
            `dirname $0`/set-args.sh EBK_POSTGRES_PASSWORD ${EBK_POSTGRES_PASSWORD}
        fi
        database_env_str="-e EBK_DATABASE_TYPE=${EBK_DATABASE_TYPE} \
        -e EBK_DATABASE_HOST=${POSTGRES_HOST}:${POSTGRES_PORT} \
        -e EBK_DATABASE_NAME=${EBK_POSTGRES_DATABASE} \
        -e EBK_DATABASE_USER=${EBK_POSTGRES_USER} \
        -e EBK_DATABASE_PASSWD=${EBK_POSTGRES_PASSWORD} "  
    ;;
    * )
    echo "不支持的数据库类型: ${EBK_DATABASE_TYPE}"
    exit 1
    ;;
esac


EBK_SERVER_DOMAIN=${container_name}.${domain}
if [ "$tls"="tls" ]; then
    EBK_SERVER_ROOT_URL="https://${EBK_SERVER_DOMAIN}"
else
    EBK_SERVER_ROOT_URL="http://${EBK_SERVER_DOMAIN}"
fi
docker pull ${image}:${EBK_VERSION}
`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
    --restart=always \
    -m 512M \
    --user=$(id -u):$(id -g) \
    --network=$docker_network_name \
    --network-alias=${container_name} \
    --hostname=${container_name} \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    ${database_env_str} \
    -e EBK_GLOBAL_MODE="production" \
    -e EBK_SERVER_DOMAIN=${EBK_SERVER_DOMAIN} \
    -e EBK_SERVER_ROOT_URL=${EBK_SERVER_ROOT_URL} \
    -e EBK_SERVER_PROTOCOL="http" \
    -e EBK_LOG_MODE="file console" \
    -e EBK_LOG_LOG_PATH="/logs/ezbookkeeping.log" \
    -e EBK_LOG_LOG_FILE_ROTATE="true" \
    -e EBK_LOG_LOG_FILE_MAX_SIZE="1048576" \
    -e EBK_LOG_LOG_FILE_MAX_DAYS="30" \
    -e EBK_STORAGE_TYPE="local_filesystem" \
    -e EBK_STORAGE_LOCAL_FILESYSTEM_PATH="/data/" \
    -e EBK_CONF_PATH="/config/ezbookkeeping.ini" \
    -v ${base_data_dir}/${container_name}/config:/config \
    -v ${base_data_dir}/${container_name}/data:/data \
    -v ${base_data_dir}/${container_name}/logs:/logs \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=8080" \
    --label "traefik.enable=true" \
${image}:${EBK_VERSION}
