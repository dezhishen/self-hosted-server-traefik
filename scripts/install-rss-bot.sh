#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=rss-bot
port=9898
image=rongronggg9/rss-to-telegram

RSS_BOT_TOKEN=$(`dirname $0`/get-args.sh RSS_BOT_TOKEN RSS机器人令牌)
if [ -z "$RSS_BOT_TOKEN" ]; then
    read -p "请输入RSS机器人令牌:" RSS_BOT_TOKEN
    if [ -z "$RSS_BOT_TOKEN" ]; then
        exit 1
    fi
    `dirname $0`/set-args.sh RSS_BOT_TOKEN "$RSS_BOT_TOKEN"
fi
RSS_BOT_MANAGER=$(`dirname $0`/get-args.sh RSS_BOT_MANAGER RSS机器人管理员)
if [ -z "$RSS_BOT_MANAGER" ]; then
    read -p "RSS机器人管理员:" RSS_BOT_MANAGER
    if [ -z "$RSS_BOT_MANAGER" ]; then
        exit 1
    fi
    `dirname $0`/set-args.sh RSS_BOT_MANAGER "$RSS_BOT_MANAGER"
fi
read -p "是否使用pregress数据库[y/n]:" use_pregress_database
if [ $use_pregress_database = "y" ]; then
    RSS_BOT_DATABASE_URL=$(`dirname $0`/get-args.sh RSS_BOT_DATABASE_URL RSS机器人数据库地址)
    if [ -z "$RSS_BOT_DATABASE_URL" ]; then
        read -p "RSS机器人数据库地址:" RSS_BOT_DATABASE_URL
    if [ -z "$RSS_BOT_DATABASE_URL" ]; then
        exit 1
    fi
    `dirname $0`/set-args.sh RSS_BOT_DATABASE_URL "$RSS_BOT_DATABASE_URL"
fi
RSS_BOT_DEBUG=$(`dirname $0`/get-args.sh RSS_BOT_DEBUG 'RSS机器人是否开启DEBUG;1/0')
if [ -z "$RSS_BOT_DEBUG" ]; then
    read -p 'RSS机器人是否开启DEBUG;1/0' RSS_BOT_DEBUG
    if [ -z "$RSS_BOT_DEBUG" ]; then
        exit 1
    fi
    `dirname $0`/set-args.sh RSS_BOT_DEBUG "$RSS_BOT_DEBUG"
fi
RSS_BOT_TELEGRAPH_TOKEN=$(`dirname $0`/get-args.sh RSS_BOT_TELEGRAPH_TOKEN 'RSS机器人TELEGRAPH_TOKEN')
if [ -z "$RSS_BOT_TELEGRAPH_TOKEN" ]; then
    read -p 'RSS机器人TELEGRAPH_TOKEN:' RSS_BOT_TELEGRAPH_TOKEN
    if [ -z "$RSS_BOT_TELEGRAPH_TOKEN" ]; then
        exit 1
    fi
    `dirname $0`/set-args.sh RSS_BOT_TELEGRAPH_TOKEN "$RSS_BOT_TELEGRAPH_TOKEN"
fi
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-d --restart=always \
-m 256M \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e DEBUG=${RSS_BOT_DEBUG} \
-e TOKEN=${RSS_BOT_TOKEN} \
-e MANAGER=${RSS_BOT_MANAGER} \
`if [ $use_pregress_database = "y" ]; then echo "-e DATABASE_URL=${RSS_BOT_DATABASE_URL}"; fi` \
-e TELEGRAPH_TOKEN=${RSS_BOT_TELEGRAPH_TOKEN} \
-v ${base_data_dir}/${container_name}/config:/app/config \
-v ${base_data_dir}/${container_name}/data:/data \
--network=$docker_network_name --network-alias=${container_name} \
--hostname=${container_name} \
${image}