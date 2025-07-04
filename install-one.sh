# !/bin/bash
set -e
# 授予可执行权限
chmod +x ./scripts/*.sh
chmod +x ./*.sh
app=$1
domain=`./scripts/get-args.sh domain "主域名(如 baidu.com或者app.baidu.com)"`
if [ -z "$domain" ]; then
    read -p "请输入主域名(如 baidu.com或者app.baidu.com):" domain
    if [ -z "$domain" ]; then
        echo "主域名不能为空"
        exit 0
    else
        ./scripts/set-args.sh domain $domain
    fi
fi
base_data_dir=`./scripts/get-args.sh base_data_dir "数据目录(如 /docker_data)"`
if [ -z "$base_data_dir" ]; then
    read -p "请输入数据目录(如 /docker_data):" base_data_dir
    if [ -z "$base_data_dir" ]; then
        echo "数据目录为空,使用默认值 /docker_data"
        base_data_dir=/docker_data
    fi
    ./scripts/set-args.sh base_data_dir $base_data_dir
    echo "文件不存在，创建文件且设置权限"
    sudo mkdir -p $base_data_dir
    sudo chown -R `id -u`:`id -g` $base_data_dir
fi

docker_network_name=`./scripts/get-args.sh docker_network_name "Docker网络名称(如 traefik)"`

if [ -z "$docker_network_name" ]; then
    read -p "请输入Docker网络名称(如 traefik):" docker_network_name
    if [ -z "$docker_network_name" ]; then
        echo "Docker网络名称为空,使用默认值 traefik"
        docker_network_name=traefik
    fi
    ./scripts/set-args.sh docker_network_name $docker_network_name
fi
tls=`./scripts/get-args.sh tls "是否开启ssl[true/false]"`
if [ -z "$tls" ]; then
    read -p "是否开启ssl[true/false]:" tls
    if [ -z "$tls" ]; then
        echo "是否开启ss为空,使用默认值 true"
        tls=true
    fi
    ./scripts/set-args.sh tls $tls
fi
sh `dirname $0`/scripts/install-$app.sh $domain $base_data_dir $docker_network_name $tls
