#!/bin/bash
set -e

docker_macvlan_network_name=$(`dirname $0`/get-args.sh docker_macvlan_network_name "macvlan的网络名")
# 如果为空,需要设置
if [ -z "$docker_macvlan_network_name" ]; then
    echo "请先运行 create-docker-macvlan-network.sh 脚本创建 macvlan 网络"
    exit 1
fi

docker_network_exists=$(docker network ls | grep $docker_macvlan_network_name | awk '{print $2}')
if [ -z "$docker_network_exists" ]; then
    echo "容器网络 $docker_macvlan_network_name 不存在,请先运行 create-docker-macvlan-network.sh 脚本创建 macvlan 网络"
    exit 1
fi

container_name=$1
if [ -z "$container_name" ]; then
    echo "请提供容器名称作为第一个参数"
    exit 1
fi

macvlan_ip=$(`dirname $0`/get-docker-macvlan-ip.sh $container_name)

# 如果不为空，则跳过
if [ -n "$macvlan_ip" ]; then
    echo "${container_name}的macvlan IP地址已设置为: $macvlan_ip"
    exit 0
fi

echo "读取与宿主机通信的macvlan网络的信息并将其作为最小化为容器分配macvlan IP地址的基础..."

forward_network_name=${docker_macvlan_network_name}_forward
forward_ip=$(ip addr show dev ${forward_network_name} | grep -v inet6 | grep inet | awk '{print $2}' | cut -d'/' -f1)
if [ -z "$forward_ip" ]; then
    echo "无法获取与宿主机通信的macvlan网络的IP地址，请检查该网络是否存在"
    exit 1
fi
forward_ip_suffix=$(echo $forward_ip | cut -d"." -f4)
forward_ip_prefix=$(echo $forward_ip | cut -d"." -f1-3)
MACVLAN_MIN_IP_SUFFIX=$((forward_ip_suffix + 1))
echo "与宿主机通信的macvlan网络的IP地址为: $forward_ip, 最小可用IP为: ${forward_ip_prefix}.${MACVLAN_MIN_IP_SUFFIX}"

# 获取最大值
MACVLAN_MAX_IP_SUFFIX=$(`dirname $0`/get-args.sh MACVLAN_MAX_IP_SUFFIX "macvlan最大IP后缀")
if [ -z "$MACVLAN_MAX_IP_SUFFIX" ]; then
    read -p "请输入macvlan最大IP后缀(例如: 50):" MACVLAN_MAX_IP_SUFFIX
    if [ -z "$MACVLAN_MAX_IP_SUFFIX" ]; then
        echo "必须提供macvlan最大IP后缀"
        exit 1
    fi
    `dirname $0`/set-args.sh MACVLAN_MAX_IP_SUFFIX "$MACVLAN_MAX_IP_SUFFIX"
fi

# 获取已经使用的IP列表
used_ip_list=""
file="$(dirname $0)/../.args/DOCKER_MACVLAN_IPS"
i=$MACVLAN_MIN_IP_SUFFIX
while [ $i -le $MACVLAN_MAX_IP_SUFFIX ]; do
    candidate_ip="${forward_ip_prefix}.$i"
    found=0
    for line in $(cat $file); do
        ip=$(echo $line | cut -d'=' -f2)
        if [ "$ip" = "$candidate_ip" ]; then
            found=1
            break
        fi
    done
    if [ $found -eq 0 ]; then
        macvlan_ip=$candidate_ip
        break
    fi
    i=$((i+1))
done

if [ -z "$macvlan_ip" ]; then
    echo "没有可用的macvlan IP地址，请检查已经使用的IP地址列表或增加MACVLAN_MAX_IP_SUFFIX的值"
    exit 1
fi
# 保存到文件
echo "${container_name}=${macvlan_ip}" >> ${file}
echo "为容器 $container_name 分配的macvlan IP地址为: $macvlan_ip"
exit 0