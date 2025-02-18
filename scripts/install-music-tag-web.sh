# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=music-tag-web
port=8002
image=xhongc/music_tag_web
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}

read -p "是否使用mysql，请输入y/n：" is_mysql
case $is_mysql in
    y)
        MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST "mysql主机" )
        MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "mysql密码" )
        MYSQL_DB_NAME=music-tag-web #$(`dirname $0`/get-args.sh MYSQL_DB_NAME "mysql数据库名" )
        MYSQL_USER=$(`dirname $0`/get-args.sh MYSQL_USER "mysql用户名" )
        if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_DB_NAME" ] || [ -z "$MYSQL_USER" ]; then
            echo "未输入mysql主机、密码、数据库名或用户名，退出安装。"
            exit 1
        fi
        ;;
esac

docker run -d --name=${container_name} \
--restart=always \
-m 1G \
--network=$docker_network_name \
--network-alias=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e DEBUG=True \
-e PUID=`id -u` -e PGID=`id -g` \
`if [ $is_mysql = "y" ]; then echo "-e MYSQL_HOST=${MYSQL_HOST} -e MYSQL_PASSWORD=${MYSQL_PASSWORD} -e MYSQL_DB_NAME=${MYSQL_DB_NAME} -e MYSQL_USER=${MYSQL_USER}"; fi` \
-e WORKER_NUM="4" \
-v $base_data_dir/${container_name}/data:/app/data \
-v $base_data_dir/${container_name}/log:/app/log \
-v $base_data_dir/public/music:/app/media \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" ${image}
