#!/bin/bash
# check if login to docker
# $HOME/.docker/config.json 是否存在
mount_volumns=""
if [ ! -f $HOME/.docker/config.json ]; then
    # 是否登录
    read -p "未登录docker hub, 是否登录? (y/n): " is_login
    if [ "$is_login" = "y" ]; then
        read -p "请输入docker hub账号: " docker_user
        docker login --username $docker_user
        if [ $? -ne 0 ]; then
            echo "登录失败, 请检查网络或账号密码"
        else
            echo "登录成功"
            mount_volumns="-v $HOME/.docker/config.json:/config.json"
        fi
    fi

else
    mount_volumns="-v $HOME/.docker/config.json:/config.json"
fi
# 排除xiaoya容器 遍历 cat /etc/DDSRem/container_name/*.txt
# 读取文件内容到数组中
container_name_list=""
for line in $(cat /etc/DDSRem/container_name/*.txt)
do
    container_name_list="$container_name_list -x $line" 
done
container_name_list="$container_name_list -x moontv "
echo "排除的容器: $container_name_list"
image=ghcr.nju.edu.cn/nicholas-fedor/watchtower
#nickfedor/watchtower
# 运行watchtower
docker run -d --name=watchtower --pull=always --rm \
     ${mount_volumns} -v /var/run/docker.sock:/var/run/docker.sock \
    --network=traefik ${image} -c ${container_name_list} --run-once  $@
