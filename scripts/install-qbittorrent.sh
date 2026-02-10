# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
image=linuxserver/qbittorrent
port=8080
container_name=qbittorrent
mkdir -p $base_data_dir/${container_name}/config \
    $base_data_dir/${container_name}/incomplete-torrents \
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

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run -d --name=${container_name} \
--restart=always \
-m 1G \
${netargs} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/${container_name}/config:/config \
-v $base_data_dir/public/downloads:/data/downloads \
-v $base_data_dir/public/9kg:/data/9kg \
-v $base_data_dir/${container_name}/incomplete-torrents:/incomplete-torrents \
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

