#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=ejbca
image=keyfactor/ejbca-ce:latest
# EJBCA 内部 HTTPS 端口，Traefik 后端使用此端口
# EJBCA 作为 CA 必须使用 HTTPS，Traefik 做 TLS 透传
port=8443

`dirname $0`/create-dir.sh $base_data_dir/${container_name}
`dirname $0`/create-dir.sh $base_data_dir/${container_name}/data

# 数据库类型选择
EJBCA_DATABASE_TYPE=$(`dirname $0`/get-args.sh EJBCA_DATABASE_TYPE "EJBCA 数据库类型[h2/mariadb/postgresql]")
if [ -z "$EJBCA_DATABASE_TYPE" ]; then
    read -p "请输入 EJBCA 数据库类型[h2/mariadb/postgresql]:" EJBCA_DATABASE_TYPE
    if [ -z "$EJBCA_DATABASE_TYPE" ]; then
        echo "使用默认值: h2"
        EJBCA_DATABASE_TYPE=h2
    fi
    `dirname $0`/set-args.sh EJBCA_DATABASE_TYPE "$EJBCA_DATABASE_TYPE"
fi

database_env_str=""

case $EJBCA_DATABASE_TYPE in
    h2)
        echo "使用内嵌 H2 数据库（仅适合测试，生产环境请使用 mariadb 或 postgresql）"
        database_env_str=" -e DATABASE_JDBC_URL=jdbc:h2:file:/mnt/persistent/h2/ejbca;DB_CLOSE_DELAY=-1"
        ;;
    mariadb)
        echo "使用 MariaDB 数据库"
        MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST "MariaDB 主机")
        if [ -z "$MYSQL_HOST" ]; then
            read -p "请输入 MariaDB 主机:" MYSQL_HOST
            if [ -z "$MYSQL_HOST" ]; then
                echo "MariaDB 主机为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_HOST "$MYSQL_HOST"
        fi
        MYSQL_PORT=$(`dirname $0`/get-args.sh MYSQL_PORT "MariaDB 端口")
        if [ -z "$MYSQL_PORT" ]; then
            read -p "请输入 MariaDB 端口:" MYSQL_PORT
            if [ -z "$MYSQL_PORT" ]; then
                echo "使用默认端口: 3306"
                MYSQL_PORT=3306
            fi
            `dirname $0`/set-args.sh MYSQL_PORT "$MYSQL_PORT"
        fi
        MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "MariaDB root 密码")
        if [ -z "$MYSQL_PASSWORD" ]; then
            read -p "请输入 MariaDB root 密码:" MYSQL_PASSWORD
            if [ -z "$MYSQL_PASSWORD" ]; then
                echo "MariaDB 密码为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_PASSWORD "$MYSQL_PASSWORD"
        fi
        database_env_str=" -e DATABASE_JDBC_URL=jdbc:mariadb://${MYSQL_HOST}:${MYSQL_PORT}/ejbca?characterEncoding=UTF-8 -e DATABASE_USER=root -e DATABASE_PASSWORD=${MYSQL_PASSWORD}"
        ;;
    postgresql)
        echo "使用 PostgreSQL 数据库"
        POSTGRES_HOST=$(`dirname $0`/get-args.sh POSTGRES_HOST "PostgreSQL 主机")
        if [ -z "$POSTGRES_HOST" ]; then
            read -p "请输入 PostgreSQL 主机:" POSTGRES_HOST
            if [ -z "$POSTGRES_HOST" ]; then
                echo "PostgreSQL 主机为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh POSTGRES_HOST "$POSTGRES_HOST"
        fi
        POSTGRES_PORT=$(`dirname $0`/get-args.sh POSTGRES_PORT "PostgreSQL 端口")
        if [ -z "$POSTGRES_PORT" ]; then
            read -p "请输入 PostgreSQL 端口:" POSTGRES_PORT
            if [ -z "$POSTGRES_PORT" ]; then
                echo "使用默认端口: 5432"
                POSTGRES_PORT=5432
            fi
            `dirname $0`/set-args.sh POSTGRES_PORT "$POSTGRES_PORT"
        fi
        POSTGRES_PASSWORD=$(`dirname $0`/get-args.sh POSTGRES_PASSWORD "PostgreSQL 密码")
        if [ -z "$POSTGRES_PASSWORD" ]; then
            read -p "请输入 PostgreSQL 密码:" POSTGRES_PASSWORD
            if [ -z "$POSTGRES_PASSWORD" ]; then
                echo "PostgreSQL 密码为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh POSTGRES_PASSWORD "$POSTGRES_PASSWORD"
        fi
        database_env_str=" -e DATABASE_JDBC_URL=jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/ejbca -e DATABASE_USER=root -e DATABASE_PASSWORD=${POSTGRES_PASSWORD}"
        ;;
    *)
        echo "不支持的数据库类型: $EJBCA_DATABASE_TYPE"
        exit 1
        ;;
esac

# 设置管理员密码
EJBCA_ADMIN_PASSWORD=$(`dirname $0`/get-args.sh EJBCA_ADMIN_PASSWORD "EJBCA 管理员密码")
if [ -z "$EJBCA_ADMIN_PASSWORD" ]; then
    read -p "请输入 EJBCA 管理员密码（留空则随机生成）:" EJBCA_ADMIN_PASSWORD
    if [ -z "$EJBCA_ADMIN_PASSWORD" ]; then
        EJBCA_ADMIN_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
        echo "随机生成密码: ${EJBCA_ADMIN_PASSWORD}"
    fi
    `dirname $0`/set-args.sh EJBCA_ADMIN_PASSWORD "$EJBCA_ADMIN_PASSWORD"
fi

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}

# EJBCA 使用 HTTPS，Traefik 通过 TLS 连接到后端
# 注意: 由于 EJBCA 内部使用自签名证书，需要配置 InsecureSkipVerify
docker run -d --name=${container_name} \
--user $(id -u):$(id -g) \
--restart=always \
-m 2G --memory-swap=3G \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
${database_env_str} \
-v $base_data_dir/${container_name}/data:/mnt/persistent \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.http.services.${container_name}.loadbalancer.server.scheme=https" \
${image}

echo "EJBCA 部署完成"
echo "访问地址: https://${container_name}.${domain}"
echo "EJBCA 管理员密码已保存至配置"
echo "首次启动可能需要等待 2-3 分钟完成初始化"
echo ""
echo "提示: 如需在 Traefik 中配置 HTTPS 后端跳过证书验证，请手动添加以下配置:"
echo "  traefik.http.services.${container_name}.loadbalancer.server.insecureskipverify=true"
