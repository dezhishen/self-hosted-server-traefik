#! /bin/bash
container_name=$1

echo "正在停止容器: $container_name"

podman ps -a -q --filter "name=$container_name" | grep -q . && podman rm -fv $container_name || echo "容器不存在"
