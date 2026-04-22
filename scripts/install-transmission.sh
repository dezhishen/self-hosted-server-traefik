# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
image=linuxserver/transmission
port=9091
container_name=transmission

TRANSMISSION_USER=$(`dirname $0`/get-args.sh TRANSMISSION_USER 用户名)
if [ -z "$TRANSMISSION_USER" ]; then
    read -p "请输入用户名:" TRANSMISSION_USER
    if [ -z "$TRANSMISSION_USER" ]; then
        echo "用户名使用默认值: admin"
        TRANSMISSION_USER="admin"
    fi
    `dirname $0`/set-args.sh TRANSMISSION_USER "$TRANSMISSION_USER"
fi

TRANSMISSION_PASSWORD=$(`dirname $0`/get-args.sh TRANSMISSION_PASSWORD 密码)
if [ -z "$TRANSMISSION_PASSWORD" ]; then
    read -p "请输入密码:" TRANSMISSION_PASSWORD
    if [ -z "$TRANSMISSION_PASSWORD" ]; then
        echo "随机生成密码"
        TRANSMISSION_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
    fi
    `dirname $0`/set-args.sh TRANSMISSION_PASSWORD "$TRANSMISSION_PASSWORD"
fi
usemacvlan=$(`dirname $0`/get-args.sh usemacvlan "是否使用macvlan[y/n]")
if [ -z "$usemacvlan" ]; then
    read -p "是否使用macvlan[y/n]:" usemacvlan
    `dirname $0`/set-args.sh usemacvlan "$usemacvlan"
fi
case $usemacvlan in
    y) 
        docker_macvlan_network_name=$(`dirname $0`/get-args.sh docker_macvlan_network_name "macvlan的网络名")
        `dirname $0`/set-docker-macvlan-ip.sh ${container_name}
        the_ip=$(`dirname $0`/get-docker-macvlan-ip.sh ${container_name})
        echo "使用ip: ${the_ip}"
        netargs="--network=${docker_macvlan_network_name} --ip=${the_ip} --hostname=${container_name}"
    ;;
    *)
        netargs="--network=${host}"
    ;;
esac
# 未完成的任务是否使用单独的文件夹存放
useincompletetorrents=$(`dirname $0`/get-args.sh USE_INCOMPLETE_TORRENTS "是否使用单独的文件夹存放未完成的任务[y/n]")

if [ -z "$useincompletetorrents" ]; then
    read -p "是否使用单独的文件夹存放未完成的任务[y/n]:" useincompletetorrents
    `dirname $0`/set-args.sh USE_INCOMPLETE_TORRENTS "$useincompletetorrents"
fi
case $useincompletetorrents in
    y) 
        # 使用单独的文件夹存放未完成的任务
        echo "使用单独的文件夹存放未完成的任务"
        `dirname $0`/set-args.sh USE_INCOMPLETE_TORRENTS "y"
        incomplete_torrents_dir=$(`dirname $0`/get-args.sh INCOMPLETE_TORRENTS_DIR "未完成的任务存放的文件夹的根目录（如: /docker_data/downloading/）")
        if [ -z "$incomplete_torrents_dir" ]; then
            read -p "请输入未完成的任务存放的文件夹的根目录（如: /docker_data/downloading）:" incomplete_torrents_dir
            if [ -z "$incomplete_torrents_dir" ]; then
                echo "未输入未完成的任务存放的文件夹的根目录，将使用默认值${base_data_dir}/${container_name}/"
            fi
            incomplete_torrents_dir=$base_data_dir/${container_name}/
            `dirname $0`/set-args.sh INCOMPLETE_TORRENTS_DIR "$incomplete_torrents_dir"
        fi
        echo "完整的未完成的任务存放的文件夹路径为: ${incomplete_torrents_dir}/${container_name}/incomplete-torrents"
        mkdir -p ${incomplete_torrents_dir}/${container_name}/incomplete-torrents
        `dirname $0`/set-args.sh INCOMPLETE_TORRENTS_DIR "$incomplete_torrents_dir"
        netargs="$netargs -v ${incomplete_torrents_dir}/${container_name}/incomplete-torrents:/incomplete-torrents "
    ;;
    *)
        # 不使用单独的文件夹存放未完成的任务，直接将未完成的任务放在finished-torrents文件夹中
        mkdir -p $base_data_dir/${container_name}/incomplete-torrents
        netargs="$netargs -v $base_data_dir/${container_name}/incomplete-torrents:/incomplete-torrents "
    ;;
esac

`dirname $0`/set-args.sh USE_INCOMPLETE_TORRENTS "$useincompletetorrents"

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
--restart=always \
-m 512M \
${netargs} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-e USER=${TRANSMISSION_USER} \
-e PASS=${TRANSMISSION_PASSWORD} \
-v $base_data_dir/${container_name}/config:/config \
-v $base_data_dir/public/downloads:/data/downloads \
-v $base_data_dir/${container_name}/finished-torrents:/finished-torrents \
${image}

case $usemacvlan in
y)
    `dirname $0`/create-traefik-provider-macvlan.sh $domain $base_data_dir $docker_macvlan_network_name $tls $container_name $port
    ;;
*)
    `dirname $0`/create-traefik-provider.sh $domain $base_data_dir $docker_network_name $tls $container_name $port
    ;;
esac
