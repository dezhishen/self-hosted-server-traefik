#!/bin/bash

domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=$5
port=$6

echo "生成traefik代理配置文件:$base_data_dir/traefik/config/providers/${container_name}.yaml"
mkdir -p $base_data_dir/traefik/config/providers
# 检验 $base_data_dir/traefik/config/providers/${container_name}.yaml 是否存在
if [ ! -f "$base_data_dir/traefik/config/providers/${container_name}.yaml" ]; then
    host_ip=$(docker network inspect ${docker_network_name} --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' | awk -F'.' '{print $1"."$2"."$3"."1}')
    echo "http:" > $base_data_dir/traefik/config/providers/${container_name}.yaml
    echo "  routers:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    echo "    ${container_name}:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    echo "      entryPoints:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    # 如果tls为true,则加入https配置
    if [ "$tls" = "true" ]; then
        echo "        - websecure" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    else 
        echo "        - web" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    fi
        echo '      rule: Host(`'${container_name}.${domain}'`)' >> $base_data_dir/traefik/config/providers/${container_name}.yaml
        echo "      service: ${container_name}" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    if [ "$tls" = "true" ]; then
        echo "      tls:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
        echo "        certresolver: traefik" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
        echo "        domains:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
        echo "        - main: '"*.${domain}"'" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    fi
    echo "  services:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    echo "    ${container_name}:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    echo "      loadBalancer:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    echo "        servers:" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
    echo "         - url: http://${host_ip}:${port}" >> $base_data_dir/traefik/config/providers/${container_name}.yaml
else
    echo "已存在traefik代理配置文件，不需要创建"
fi
echo "文件内容:"
cat $base_data_dir/traefik/config/providers/${container_name}.yaml