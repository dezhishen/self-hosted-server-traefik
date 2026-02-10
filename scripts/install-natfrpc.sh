#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
container_name=natfrpc
image=ghcr.io/natfrp/frpc:latest
NATFRPC_TOKEN=$(`dirname $0`/get-args.sh NATFRPC_TOKEN token)
if [ -z "$NATFRPC_TOKEN" ]; then
    read -p "请输入token:" NATFRPC_TOKEN
    if [ -z "$NATFRPC_TOKEN" ]; then
        echo "必须提供token"
        exit 1
    fi
    `dirname $0`/set-args.sh NATFRPC_TOKEN ${NATFRPC_TOKEN}
fi

NATFRPC_TUNNELS=$(`dirname $0`/get-args.sh NATFRPC_TUNNELS '隧道列表，用,隔开')
if [ -z "$NATFRPC_TUNNELS" ]; then
    read -p "请输入 隧道列表:" NATFRPC_TUNNELS
    if [ -z "$NATFRPC_TUNNELS" ]; then
        echo "必须提供隧道列表"
        exit 1
    fi
    `dirname $0`/set-args.sh NATFRPC_TUNNELS ${NATFRPC_TUNNELS}
fi

docker rm -f ${container_name} 
docker run -d --restart=always --name=${container_name} \
--network=${docker_network_name} --network-alias=${container_name} \
--memory=64M --memory-swap 128M \
-e TZ=Asia/Shanghai \
${image} -f ${NATFRPC_TOKEN}:${NATFRPC_TUNNELS}

