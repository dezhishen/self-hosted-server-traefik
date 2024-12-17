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
MYSQL_PORT_MAPPING=$(`dirname $0`/get-args.sh MYSQL_PORT_MAPPING 是否映射端口[y/n])
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