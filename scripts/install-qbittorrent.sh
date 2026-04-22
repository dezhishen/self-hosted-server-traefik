# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
image=linuxserver/qbittorrent
port=8080
container_name=qbittorrent
mkdir -p $base_data_dir/${container_name}/config \
    $base_data_dir/${container_name}/finished-torrents
usemacvlan=$(`dirname $0`/get-args.sh usemacvlan "是否使用macvlan[y/n]")
if [ -z "$usemacvlan" ]; then
    read -p "是否使用macvlan[y/n]:" usemacvlan
    `dirname $0`/set-args.sh usemacvlan "$usemacvlan"
fi
case $usemacvlan in
    y) 
        # 创建macvlan
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
-m 1G \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
${netargs} \
-v $base_data_dir/${container_name}/config:/config \
-v $base_data_dir/public/downloads:/data/downloads \
-v $base_data_dir/public/9kg:/data/9kg \
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

