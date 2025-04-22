#!/bin/bash
# check if login to docker
# $HOME/.docker/config.json 是否存在
mount_volumns=""
if [ ! -f $HOME/.docker/config.json ]; then
    # 是否登录
    read -p "未登录docker hub, 是否登录? (y/n): " is_login
    if [ "$is_login" == "y" ]; then
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
while read line
do
    container_name_list="$container_name_list $line"
done < /etc/DDSRem/container_name/*.txt
echo "排除的容器: $container_name_list"
# 运行watchtower
docker run --name=watchtower --rm \
-d ${mount_volumns} -v /var/run/docker.sock:/var/run/docker.sock \
--network=traefik containrrr/watchtower -c --disable-containers ${container_name_list} --run-once  $@