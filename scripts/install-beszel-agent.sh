# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=beszel-agent
image=henrygd/beszel-agent
port=45876


`dirname $0`/stop-container.sh ${container_name}
envs=""
echo "使用ssh连接到hub"
echo "尝试从beszel容器获取公钥"
path=${base_data_dir}/beszel/data/id_ed25519.pub
if [ -f "$path" ]; then
    public_key=$(cat $path)
    # trim the public key
    public_key=$(echo $public_key | tr -d '\n')
    echo "获取到公钥: ${public_key}"
fi
if [ -z "$public_key" ]; then
    read -p "未获取到公钥，请从beszel容器内的/beszel_data/id_ed25519.pub文件中获取公钥，并输入：" public_key
    if [ -z "$public_key" ]; then
        echo "公钥不能为空，退出"
        exit 1
    fi
fi
use_websocket=$(`dirname $0`/get-args.sh BESZEL_USE_WEBSOCKET "是否使用WebSocket连接到hub[y/n]")
if [ -z "$use_websocket" ]; then
    read -p "是否使用WebSocket 连接到hub（y/n，默认n）:" use_websocket
    if [ -z "$use_websocket" ]; then
        use_websocket="n"
    fi
    `dirname $0`/set-args.sh BESZEL_USE_WEBSOCKET "$use_websocket"
fi
case $use_websocket in
    y|Y)
        echo "使用WebSocket连接到hub"
        HUB_URL=$(`dirname $0`/get-args.sh BESZEL_HUB_URL "beszel hub地址")
        if [ -z "$HUB_URL" ]; then
            read -p "请输入beszel hub地址（默认 http://beszel:8090 ):" HUB_URL
            if [ -z "$HUB_URL" ]; then
                HUB_URL="http://beszel:8090"
            fi
            `dirname $0`/set-args.sh HUB_URL "$BESZEL_HUB_URL"
        fi
        TOKEN=$(`dirname $0`/get-args.sh BESZEL_TOKEN "beszel的令牌")
        if [ -z "$TOKEN" ]; then
            read -p "请输入Beszel的Token:" TOKEN
            if [ -z "$TOKEN" ]; then
                echo "Token不能为空，退出"
                exit 1
            fi
        fi
        `dirname $0`/set-args.sh BESZEL_TOKEN "$TOKEN"
        envs="${envs} -e HUB_URL=${HUB_URL} -e TOKEN=${TOKEN}"
        ;;
    *)
        ;;
esac
DOCKER_HOST=$(`dirname $0`/get-args.sh BESZEL_DOCKER_HOST "Docker Host地址")
echo "envs: ${envs}"
docker pull ${image}
docker run -d --name=${container_name} \
--restart=always --network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-e TZ="Asia/Shanghai" -e LANG="zh_CN.UTF-8" -e PORT=45876 \
-e KEY="${public_key}" ${envs} \
-m 64M \
-v /var/run/docker.sock:/var/run/docker.sock:ro \
$image