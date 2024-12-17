# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=adguardhome
image=adguard/adguardhome

`dirname $0`/create-dir.sh $base_data_dir/${container_name}
`dirname $0`/create-dir.sh $base_data_dir/${container_name}/work
`dirname $0`/create-dir.sh $base_data_dir/${container_name}/conf


# rule=Host(`adguardhome.'$domain'`)'
`dirname $0`/stop-container.sh adguardhome
# 是否为第一次安装
if [ ! -f "$base_data_dir/${container_name}/conf/AdGuardHome.yaml" ]; then
    port=3000
    docker run -d --restart=always \
        --name=${container_name} \
        -m 64M  --hostname=${container_name} \
        --network=$docker_network_name \
        --network-alias=${container_name} \
        -p 53:53 -p 53:53/udp \
        -e TZ="Asia/Shanghai" \
        -e LANG="zh_CN.UTF-8" \
        -v $base_data_dir/${container_name}/work:/opt/${container_name}/work \
        -v $base_data_dir/${container_name}/conf:/opt/${container_name}/conf \
        --label 'traefik.http.routers.'${container_name}'.rule=Host(`*.'$domain'`)' \
        --label "traefik.http.routers.${container_name}.tls=${tls}" \
        --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
        --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
        --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
        --label "traefik.enable=true" \
    ${image}
    echo "请访问 https://${container_name}.$domain 初始化安装"
    echo "初始化请设置端口为80,随后重新安装"
else
    bind_port=`cat $base_data_dir/${container_name}/conf/AdGuardHome.yaml | grep -E '^bind_port:' | awk -F ':' '{print $2}' | sed 's/ //g'`
    # 如果bind_port为空,则报错
    if [ -z "$bind_port" ]; then
        echo "AdGuardHome.yaml文件中bind_port配置错误,请检查"
        exit 1
    fi
    docker run -d --restart=always \
        --name=${container_name} \
        -m 128M --memory-swap=256M \
        --network=$docker_network_name \
        --network-alias=${container_name} \
        -p 53:53 -p 53:53/udp \
        -e TZ="Asia/Shanghai" \
        -e LANG="zh_CN.UTF-8" \
        -v $base_data_dir/${container_name}/work:/opt/${container_name}/work \
        -v $base_data_dir/${container_name}/conf:/opt/${container_name}/conf \
        --label 'traefik.http.routers.${container_name}.rule=Host(`adguardhome.'$domain'`)' \
        --label "traefik.http.routers.${container_name}.tls=${tls}" \
        --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
        --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
        --label "traefik.http.services.${container_name}.loadbalancer.server.port=$bind_port" \
        --label "traefik.enable=true" \
    adguard/adguardhome
    echo "请访问 http://adguardhome.$domain"
fi
