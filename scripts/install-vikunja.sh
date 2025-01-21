#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=vikunja
image=vikunja/vikunja
port=3456
# 创建文件夹
mkdir -p ${base_data_dir}/${container_name}/files
MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD 密码)                           
if [ -z "$MYSQL_PASSWORD" ]; then                                                          
    read -p "请输入密码:" MYSQL_PASSWORD                                                        
    if [ -z "$MYSQL_PASSWORD" ]; then                                                      
        echo "随机生成密码"                                                                          
        MARIADB_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`  
    fi                                                                                         
    `dirname $0`/set-args.sh MYSQL_PASSWORD "$MYSQL_PASSWORD"                          
fi       
VIKUNJA_SERVICE_JWTSECRET=$(`dirname $0`/get-args.sh VIKUNJA_SERVICE_JWTSECRET jwt加密key)
if [ -z "$VIKUNJA_SERVICE_JWTSECRET" ]; then
    read -p "请输入jwt加密key:" VIKUNJA_SERVICE_JWTSECRET
    if [ -z "$VIKUNJA_SERVICE_JWTSECRET" ]; then
        echo "随机生成jwt加密key"
        VIKUNJA_SERVICE_JWTSECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
        echo "jwt加密key为${VIKUNJA_SERVICE_JWTSECRET}"
    fi
    `dirname $0`/set-args.sh VIKUNJA_SERVICE_JWTSECRET "$VIKUNJA_SERVICE_JWTSECRET"
fi


docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}

docker run --name=${container_name} \
-m 128M \
-d --restart=always \
-e VIKUNJA_SERVICE_PUBLICURL=https://${container_name}.$domain \
-e VIKUNJA_DATABASE_HOST=mariadb \
-e VIKUNJA_DATABASE_PASSWORD=${MYSQL_PASSWORD} \
-e VIKUNJA_DATABASE_TYPE=mysql \
-e VIKUNJA_DATABASE_USER=root \
-e VIKUNJA_DATABASE_DATABASE=vikunja \
-e VIKUNJA_SERVICE_JWTSECRET=${VIKUNJA_SERVICE_JWTSECRET} \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-v ${base_data_dir}/${container_name}/files:/app/vikunja/files \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}