# !/bin/bash
docker_macvlan_network_name=$(`dirname $0`/get-args.sh docker_macvlan_network_name "macvlan的网络名")
# 如果为空,需要设置
if [ -z "$docker_macvlan_network_name" ]; then
    read -p "请输入macvlan的网络名:" docker_macvlan_network_name
    if [ -z "$docker_macvlan_network_name" ]; then
        echo "macvlan的网络名使用默认值: macvlan"
        docker_macvlan_network_name="macvlan"
    fi
    `dirname $0`/set-args.sh docker_macvlan_network_name "$docker_macvlan_network_name"
fi

docker_network_exists=$(docker network ls | grep $docker_macvlan_network_name | awk '{print $2}')
if [ -n "$docker_network_exists" ]; then
    echo "容器网络 $docker_macvlan_network_name 已存在"
    #if $docker_macvlan_network_name's driver != macvlan exit
    docker_network_driver=$(docker network inspect $docker_macvlan_network_name | grep Driver | awk '{print $2}' | grep macvlan)
    if [ -z "$docker_network_driver" ]; then
        echo "容器网络 $docker_macvlan_network_name 的驱动不是macvlan,请检查"
        exit 0
    fi
else
    the_gateway=$(ip route get 1.1.1.1 | awk 'N=3 {print $N}')
    the_subnet=$(echo $the_gateway | cut -d"." -f1-3).0/24
    docker network create $docker_macvlan_network_name -d macvlan --subnet=$the_subnet --gateway=$the_gateway
    echo "容器网络 $docker_macvlan_network_name 创建成功"
fi
