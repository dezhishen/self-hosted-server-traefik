#!/bin/bash
# docker run -itd -p 6185:6185 -p 6199:6199 -v $PWD/data:/AstrBot/data -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro --name astrbot m.daocloud.io/docker.io/soulter/astrbot:latest
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

read -p "Do you want to install AstrBot? (y/n) " install_astrbot
case $install_astrbot in
    [Yy]* ) 
        container_name=astrbot 
        image=soulter/astrbot
        port=6185

        mkdir -p ${base_data_dir}/${container_name}/data
        docker pull $image
        docker stop $container_name > /dev/null
        docker rm $container_name
        docker run --restart=always -d --name ${container_name} \
            -m 128M \
            --user=`id -u`:`id -g` \
            -v ${base_data_dir}/${container_name}/data:/AstrBot/data \
            --network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name} \
            --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
            --label "traefik.http.routers.${container_name}.tls=${tls}" \
            --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
            --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
            --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
            --label "traefik.enable=true" \
        ${image}
    ;;
esac
read -p "Do you want to install shipyard? (y/n) " install_shipyard

case $install_shipyard in
    [Yy]* ) 
        container_name=astrbot-shipyard
        image=ghcr.io/astrbotdevs/shipyard-neo-bay:latest
        port=8114
        docker_group_id=$(cat /etc/group | grep -e docker | cut -d ":" -f 3)
        # echo "开始设置BAY_API_KEY"
        bay_api_key=$(`dirname $0`/get-args.sh ASTRBOT_BAY_API_KEY BAY_API_KEY)
        if [ -z "$bay_api_key" ]; then
            echo "未设置ASTRBOT_BAY_API_KEY环境变量，将使用随机生成的API密钥"
            bay_api_key=$(openssl rand -hex 16)
            echo "生成的API密钥为: $bay_api_key"
            `dirname $0`/set-args.sh ASTRBOT_BAY_API_KEY $bay_api_key
        fi
        mkdir -p ${base_data_dir}/${container_name}/data
        mkdir -p ${base_data_dir}/${container_name}/config
        mkdir -p ${base_data_dir}/${container_name}/cargos
        touch ${base_data_dir}/${container_name}/config/config.yaml
        docker pull $image
        docker stop $container_name > /dev/null
        docker rm $container_name
        docker run --restart=always -d --name ${container_name} \
            --network=${docker_network_name} --network-alias=${container_name} --hostname=${container_name} \
            --user=`id -u`:`id -g` \
            -e BAY_API_KEY=$bay_api_key \
            -e BAY_CONFIG_FILE=/app/config/config.yaml \
            -e BAY_DATA_DIR=/app/data \
            -v ${base_data_dir}/${container_name}/config/config.yaml:/app/config/config.yaml:ro \
            -v ${base_data_dir}/${container_name}/data:/app/data \
            -v ${base_data_dir}/${container_name}/cargos:/var/lib/bay/cargos \
            -v /var/run/docker.sock:/var/run/docker.sock \
            --group-add ${docker_group_id} \
            --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
            --label "traefik.http.routers.${container_name}.tls=${tls}" \
            --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
            --label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
            --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
            --label "traefik.enable=true" \
        ${image}
    ;;
esac