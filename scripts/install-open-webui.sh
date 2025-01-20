#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
read -p "是否安装open-webui[Y/N]:" yn
if [ "$yn" = "Y" ]; then
    container_name=open-webui
    port=8080 
    image=ghcr.io/open-webui/open-webui:main

    open_webui_web_auth=$(`dirname $0`/get-args.sh open_webui_web_auth "是否开启web认证[Y/N]")
    if [ -z "$open_webui_web_auth" ]; then
        read -p "是否开启web认证[Y/N]:" open_webui_web_auth
        if [ -z "$open_webui_web_auth" ]; then
            echo "是否开启web认证为空,使用默认值 N"
            open_webui_web_auth=N
        fi
        `dirname $0`/set-args.sh open_webui_web_auth "$open_webui_web_auth"
    fi
    if [ "$open_webui_web_auth" = "Y" ]; then
        web_auth_args=""
    else
        web_auth_args="-e WEBUI_AUTH=False"
    fi
    docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}
    docker run --name=${container_name} \
    -d --restart=always \
    -m 1024M \
    ${web_auth_args} \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    -v ${base_data_dir}/open-webui/data:/app/backend/data \
    --network=$docker_network_name --network-alias=${container_name} \
    --hostname=${container_name} \
    --label "traefik.enable=true" \
    --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
    --label "traefik.http.routers.${container_name}.tls=${tls}" \
    --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
    --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.${container_name}.loadbalancer.server.port=$port" \
    ${image}
fi
read -p "是否安装ollama[Y/N]:" yn
if [ "$yn" = "Y" ]; then
    container_name=ollama
    port=11434 
    image=ollama/ollama:latest
    echo "请选择ollama的设备"
    echo """
    1. cpu
    2. nvidia-cuda
    3. amd
    """
    ollama_device=$(`dirname $0`/get-args.sh ollama_device "ollama的设备")
    if [ -z "$ollama_device" ]; then
        read -p "请选择ollama的设备:" ollama_device
        if [ -z "$ollama_device" ]; then
            echo "ollama的设备不能为空"
            exit 1
        fi
        `dirname $0`/set-args.sh ollama_device "$ollama_device"
    fi
    if [ "$ollama_device" = "1" ]; then
        ollama_device_args=""
    elif [ "$ollama_device" = "2" ]; then
        ollama_device_args="--gpus all"
    elif [ "$ollama_device" = "3" ]; then
        ollama_device_args="--device /dev/kfd --device /dev/dri"
        image="ollama/ollama:rocm"
    fi
    docker pull ${image}
    `dirname $0`/stop-container.sh ${container_name}
    docker run --name=${container_name} -d \
    --restart=always \
    -v ${base_data_dir}/ollama/data:/root/.ollama \
    --network=${docker_network_name} --network-alias=${container_name} \
    --hostname=${container_name} \
    ${ollama_device_args} \
    ${image}
fi
read -p "是否需要拉取ollama的模型[Y/N]:" yn
if [ "$yn" = "Y" ]; then
    read -p "请输入ollama的模型名称:" ollama_model
    docker exec -it ${container_name} ollama pull ${ollama_model}
fi