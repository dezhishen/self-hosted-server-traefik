# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3

echo "请选择服务架构: "
echo "1. x86-64	"
echo "2. arm64"
echo "3. armhf"
read -p "请输入序号: " num
case $num in
    1 )
        arch="amd64"
        ;;
    2 )
        arch="arm64v8"
        ;;
    3 )
        arch="arm32v7"
        ;;
    * )
        echo "输入错误,即将退出安装..."
        exit 0
        ;;
esac

`dirname $0`/stop-container.sh bazarr

docker run -d \
--restart=always \
--name=bazarr \
-m 64M --memory-swap=128M \
--network=$docker_network_name \
--network-alias=bazarr \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PUID=`id -u` -e PGID=`id -g` \
-v $base_data_dir/bazarr/config:/config \
-v $base_data_dir/public/:/data \
--label 'traefik.http.routers.bazarr.rule=Host(`bazarr'.$domain'`)' \
--label "traefik.http.routers.bazarr.tls=true" \
--label "traefik.http.routers.bazarr.tls.certresolver=traefik" \
--label "traefik.http.routers.bazarr.tls.domains[0].main=bazarr.$domain" \
--label "traefik.http.services.bazarr.loadbalancer.server.port=6767" \
--label "traefik.enable=true" \
lscr.io/linuxserver/bazarr:$arch-latest