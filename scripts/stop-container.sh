#! /bin/bash
container_name=$1

echo "正在停止容器: $container_name"

docker ps -a -q --filter "name=$container_name" | grep -q . && docker rm -fv $container_name || echo "容器不存在"
