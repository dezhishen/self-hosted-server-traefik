#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=redis
image=valkey/valkey #redis
port=6379
REDIS_PASSWORD_SET=$(`dirname $0`/get-args.sh REDIS_PASSWORD_SET 是否设置密码[y/n])
if [ -z "$REDIS_PASSWORD_SET" ]; then
    read -p "是否设置密码[y/n]:" REDIS_PASSWORD_SET
    if [ -z "$REDIS_PASSWORD_SET" ]; then
        echo "输入不能为空"
        exit 1
    fi
    `dirname $0`/set-args.sh REDIS_PASSWORD_SET ${REDIS_PASSWORD_SET}
fi
if [ $REDIS_PASSWORD_SET = "y" ]; then
    REDIS_PASSWORD=$(`dirname $0`/get-args.sh REDIS_PASSWORD 密码)
    if [ -z "$REDIS_PASSWORD" ]; then
        read -p "密码:" REDIS_PASSWORD
        if [ -z "$REDIS_PASSWORD" ]; then
            echo "输入不能为空"
            exit 1
        fi
        `dirname $0`/set-args.sh REDIS_PASSWORD ${REDIS_PASSWORD}
    fi
fi

REDIS_PORT_MAPPING=$(`dirname $0`/get-args.sh REDIS_PORT_MAPPING 是否映射端口[y/n])
if [ -z "$REDIS_PORT_MAPPING" ]; then
    read -p "是否映射端口[y/n]:" REDIS_PORT_MAPPING
    if [ -z "$REDIS_PORT_MAPPING" ]; then
        echo "输入不能为空"
        exit 1
    fi
    `dirname $0`/set-args.sh REDIS_PORT_MAPPING ${REDIS_PORT_MAPPING}
fi

REDIS_PORT_MAPPING_LAN=$(`dirname $0`/get-args.sh REDIS_PORT_MAPPING_LAN 是否只允许局域网访问[y/n])
if [ -z "$REDIS_PORT_MAPPING_LAN" ]; then
    read -p "是否只允许局域网访问[y/n]:" REDIS_PORT_MAPPING_LAN
    if [ -z "$REDIS_PORT_MAPPING_LAN" ]; then
        echo "默认为y"
	REDIS_PORT_MAPPING_LAN="y"
    fi
    `dirname $0`/set-args.sh REDIS_PORT_MAPPING_LAN ${REDIS_PORT_MAPPING_LAN}
fi
port_mapping=""
if [ "$REDIS_PORT_MAPPING"="y" ]; then
    echo "开启端口映射"
    if [ "$REDIS_PORT_MAPPING_LAN"="y" ]; then
        local_ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
	echo "本地ip: ${local_ip}"
        port_mapping="-p ${local_ip}:${port}:${port}"
    else
	port_mapping="-p ${port}:${port}"
    fi
fi
docker pull $image
`dirname $0`/stop-container.sh ${container_name}
docker run --restart=always -d --name ${container_name} -m 512M \
${port_mapping} \
-v ${base_data_dir}/${container_name}/data:/data \
--network=${docker_network_name} --network-alias=${container_name} \
--hostname=${container_name} --user $(id -u):$(id -g) \
${image} `if [ $REDIS_PASSWORD_SET = "y" ]; then echo "--requirepass ${REDIS_PASSWORD}"; fi`

echo "redis 启动成功"
echo "设置REDIS_HOST=${container_name}"
`dirname $0`/set-args.sh REDIS_HOST ${container_name}
echo "设置REDIS_PORT=${port}"
`dirname $0`/set-args.sh REDIS_PORT ${port}
echo "设置REDIS_PASSWORD=${REDIS_PASSWORD}"
`dirname $0`/set-args.sh REDIS_PASSWORD ${REDIS_PASSWORD}

