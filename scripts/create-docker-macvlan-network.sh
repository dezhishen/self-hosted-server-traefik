# !/bin/bash
set -e
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
    # 获取宿主机的网络接口名称
    parent_interface=$(ip route show default | awk '{print $5}')
    the_gateway=$(ip -4 route show default | awk '{print $3}')
    the_subnet=$(echo $the_gateway | cut -d"." -f1-3).0/24
    the_ipv6_gateway=$(ip -6 route show default | awk '{print $3}')
    # 获取ipv6的子网信息
    ## 截取 网关的 前4个字符
    the_ipv6_gateway_prefix=$(echo $the_ipv6_gateway | cut -c1-4)
    the_ipv6_subnet=$(ip addr show dev enp6s18 | grep inet6 | grep $the_ipv6_gateway_prefix | awk '{print $2}' | head -n 1)
    echo "即将创建macvlan网络，使用的物理网卡为: $parent_interface, 子网: $the_subnet, 网关: $the_gateway"
    echo "创建语句 为: "
    echo "docker network create -d macvlan"
    echo "--subnet=$the_subnet --gateway=$the_gateway"
    echo "--subnet=${the_ipv6_subnet} --gateway=${the_ipv6_gateway}"
    echo "-o parent=${parent_interface} $docker_macvlan_network_name "
    docker network create -d macvlan \
        --subnet="$the_subnet" --gateway="$the_gateway" \
        --subnet="${the_ipv6_subnet}" --gateway="${the_ipv6_gateway}" \
        -o parent="${parent_interface}" "$docker_macvlan_network_name"
    echo "容器网络 $docker_macvlan_network_name 创建成功"
fi
read -p "是否需要创建与宿主机通信的macvlan网络（y/N）？" yN
case $yN in
    [Yy]* )
    echo "即将创建与宿主机通信的macvlan网络"
    docker_macvlan_forward_ip=$(`dirname $0`/get-args.sh docker_macvlan_forward_ip "与宿主机通信的macvlan网络的IP地址")
    if [ -z "$docker_macvlan_forward_ip" ]; then
        # 创建与宿主机通信的macvlan网络
        read -p "请输入与宿主机通信的macvlan网络的IP地址。当前子网为${the_subnet}，请确保IP地址在此子网内且未被占用:" forward_ip
        if [ -z "$forward_ip" ]; then
            echo "必须提供与宿主机通信的macvlan网络的IP地址"
            exit 1
        fi
        docker_macvlan_forward_ip="$forward_ip"
        `dirname $0`/set-args.sh docker_macvlan_forward_ip "$docker_macvlan_forward_ip"
    fi
    sudo sh `dirname $0`/create-macvlan-systemd.sh $docker_macvlan_network_name $docker_macvlan_forward_ip
    ;;
    * )
    echo "跳过创建与宿主机通信的macvlan网络"
    ;;
esac

