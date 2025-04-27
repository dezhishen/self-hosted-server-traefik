#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=mariadb
image=mariadb:11.3.2
port=3306
MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD 密码)                           
if [ -z "$MYSQL_PASSWORD" ]; then                                                          
    read -p "请输入密码:" MYSQL_PASSWORD                                                        
    if [ -z "$MYSQL_PASSWORD" ]; then                                                      
        echo "随机生成密码"                                                                          
        MARIADB_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`  
    fi                                                                                         
    `dirname $0`/set-args.sh MYSQL_PASSWORD "$MYSQL_PASSWORD"                          
fi  
read -p "是否重装 mariadb ? [y/n] " install_mariadb
if [ "$install_mariadb" = "y" ]; then
    MYSQL_PORT_MAPPING=$(`dirname $0`/get-args.sh MYSQL_PORT_MAPPING 是否映射端口[y/n])
    if [ -z "$MYSQL_PORT_MAPPING" ]; then                                                          
        read -p "是否映射端口[y/n]:" MYSQL_PORT_MAPPING                                                        
        if [ -z "$MYSQL_PORT_MAPPING" ]; then                                                      
            echo "是否映射端口[y/n]为空，默认不映射端口"
            MYSQL_PORT_MAPPING="n"                                                                       
        fi                                                                                         
        `dirname $0`/set-args.sh MYSQL_PORT_MAPPING "$MYSQL_PORT_MAPPING"                          
    fi    
    docker pull $image
    docker stop $container_name > /dev/null
    docker rm $container_name
    docker run --restart=always -d --name ${container_name} -m 512M \
    --user=`id -u`:`id -g` \
    -e TZ=Asia/Shanghai \
    -e LANG=zh_CN.UTF-8 \
    -e MARIADB_USER=root \
    -e MARIADB_ROOT_PASSWORD=${MYSQL_PASSWORD} \
    `if [ $MYSQL_PORT_MAPPING = "y" ]; then echo "-p ${port}:${port}"; fi` \
    -v ${base_data_dir}/${container_name}/data:/var/lib/mysql:Z \
    --network=${docker_network_name} --network-alias=${container_name} \
    ${image}
    echo "设置mysql_host为${container_name}"
    `dirname $0`/set-args.sh MYSQL_HOST "${container_name}"
    echo "设置mysql_port为${port}"
    `dirname $0`/set-args.sh MYSQL_PORT "${port}"
fi
mariadb_container_name=${container_name}

read -p "是否重装 备份程序 ? [y/n] " install_mariadb_backup
if [ "$install_mariadb_backup" = "y" ]; then
    container_name=mariadb-backup
    image=databack/mysql-backup
    # 创建备份目录，避免权限问题
    if [ ! -d ${base_data_dir}/${container_name}/backup ]; then
        mkdir -p ${base_data_dir}/${container_name}/backup
    fi
    MYSQL_HOST=${mariadb_container_name}
    MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "mysql密码" )
    read -p "是否单次备份[y/n]:" backup_once
    if [ "$backup_once" = "y" ]; then
        docker pull $image
        docker stop $container_name-once > /dev/null
        docker rm $container_name-once
        docker run --rm -it \
        --hostname=${container_name} \
        --name ${container_name}-once -m 64M \
        --network=${docker_network_name} --network-alias=${container_name} \
        --user=`id -u`:`id -g` \
        -e TZ=Asia/Shanghai \
        -e LANG=zh_CN.UTF-8 \
        -e DB_SERVER=${MYSQL_HOST} \
        -e DB_USER=root \
        -e DB_PASS=${MYSQL_PASSWORD} \
        -e DB_DUMP_TARGET=/db \
        -v ${base_data_dir}/${container_name}/backup/:/db \
        ${image} dump --once
    else
        docker pull $image
        docker stop $container_name > /dev/null
        docker rm $container_name
        docker run --restart=always -d \
        --hostname=${container_name} \
        --name ${container_name} -m 64M \
        --user=`id -u`:`id -g` \
        -e TZ=Asia/Shanghai \
        -e LANG=zh_CN.UTF-8 \
        -e DB_SERVER=${MYSQL_HOST} \
        -e DB_USER=root \
        -e DB_PASS=${MYSQL_PASSWORD} \
        -e DB_DUMP_FREQUENCY=60 \
        -e DB_DUMP_BEGIN=0000 \
        -e DB_DUMP_TARGET=/db \
        -v ${base_data_dir}/${container_name}/backup/:/db \
        --network=${docker_network_name} --network-alias=${container_name} \
        ${image} dump
    fi
fi