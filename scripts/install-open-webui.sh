#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=open-webui
port=8080
image=ghcr.docker.sdniu.top/open-webui/open-webui:main

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
open_webui_ollama_url=$(`dirname $0`/get-args.sh open_webui_ollama_url "请输入ollama的url")
if [ -z "$open_webui_ollama_url" ]; then
    read -p "请输入ollama的url:" open_webui_ollama_url
    if [ -z "$open_webui_ollama_url" ]; then
        echo "未找到ollama"
        exit 1
    fi
    `dirname $0`/set-args.sh open_webui_ollama_url "$open_webui_ollama_url"
fi
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-m 1024M \
${web_auth_args} \
-e OLLAMA_BASE_URL=$open_webui_ollama_url \
-e HF_ENDPOINT=https://hf-mirror.com/ \
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
