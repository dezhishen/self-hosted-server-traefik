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
    # 优先读取github上的traefik-providers-template.yaml文件内容到template变量，如果异常则读取本地文件../template/traefik-providers-template.yaml
    template=$(curl -s https://raw.githubusercontent.com/dezhishen/self-hosted-server-traefik/master/template/traefik-providers-template.yaml || cat ../template/traefik-providers-template.yaml)
    # 替换template中的变量
    # 如果tls为true,则替换entryPoint为websecure,否则替换为web
    if [ "$tls" = "true" ]; then
        entryPoint="websecure"
    else
        entryPoint="web"
    fi
    # 替换template中的变量
    template=$(echo "$template" | sed "s/\${container_name}/${container_name}/g")
    template=$(echo "$template" | sed "s/\${domain}/${domain}/g")
    template=$(echo "$template" | sed "s/\${host_ip}/${host_ip}/g")
    template=$(echo "$template" | sed "s/\${port}/${port}/g")
    template=$(echo "$template" | sed "s/\${entryPoint}/${entryPoint}/g")
    echo "$template" > $base_data_dir/traefik/config/providers/${container_name}.yaml
else
    echo "已存在traefik代理配置文件，不需要创建"
fi
echo "文件内容:"
cat $base_data_dir/traefik/config/providers/${container_name}.yaml


