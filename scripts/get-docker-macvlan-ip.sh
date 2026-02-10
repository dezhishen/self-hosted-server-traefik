#! /bin/bash
set -e
function get_used_macvlan_ip(){
    container_name=$1
    file=$(dirname $0)/../.args/DOCKER_MACVLAN_IPS
    # 判断文件是否存在
    if [ ! -f "$file" ]; then
        touch $file
        echo ""
        exit 0
    fi
    cat ${file} | grep -v "^#" | while read line; do
        args_name=$(echo $line | cut -d'=' -f1)
        ip_address=$(echo $line | cut -d'=' -f2)
        if [ "$args_name" == "${container_name}" ]; then
            echo $ip_address
            exit 0
        fi
    done
    echo ""
}

echo $(get_used_macvlan_ip $@)
