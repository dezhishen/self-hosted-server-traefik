#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
image=cloudflare/cloudflared:latest

container_name="cloudflared"

cloudflared_login(){
    echo "即将登录 cloudflare，请按照文字，打开浏览器并且授权"
    `dirname $0`/create-dir.sh $base_data_dir/${container_name}/etc
    docker run -it --name=${container_name}-login \
    -e TUNNEL_CRED_FILE=/etc/cloudflared/cerd-traefik.json \
    -v ${base_data_dir}/${container_name}/etc:/etc/cloudflared/ ${image} login
    sudo docker cp ${container_name}-login:/home/nonroot/.cloudflared/cert.pem ${base_data_dir}/${container_name}/etc/
    sudo chown -R `id -u`:`id -g` ${base_data_dir}/${container_name}/etc
    sudo chmod -R 777 ${base_data_dir}/${container_name}/etc
    docker rm -f ${container_name}-login
}

cloudflared_tunnel_create(){
    tunnel_name=$1
    docker run --rm -it --name=${container_name}-create \
    -v ${base_data_dir}/${container_name}/etc:/etc/cloudflared/ ${image} tunnel create ${tunnel_name}
    CLOUDFLARED_TUNNEL_ID=${tunnel_name}
}


cloudflared_check(){
    tunnel_name=$1
    result=`docker run --rm -it --name=${container_name}-check \
    -v ${base_data_dir}/${container_name}/etc:/etc/cloudflared/ ${image} tunnel info ${tunnel_name} `
    # 如果结果中包含"error"，则表示tunnel id不存在
    echo "执行结果: $result"
    check_result=`echo $result | grep "error"`
    if [ -n "$check_result" ]; then
        echo "tunnel id不存在，将进行创建"
        cloudflared_tunnel_create ${tunnel_name}
    fi
}


read -p "是否进行登录 cloudflare(ps:仅第一次安装需要) [y/n]:" yN
case $yN in
    y|Y|yes|Yes|YES)
        cloudflared_login
        ;;
esac

CLOUDFLARED_TUNNEL_ID=$(`dirname $0`/get-args.sh CLOUDFLARED_TUNNEL_ID tunnel_id)
if [ -z "$CLOUDFLARED_TUNNEL_ID" ]; then
    read -p "请输入cloudflared tunnel id:" CLOUDFLARED_TUNNEL_ID
    if [ -z "$CLOUDFLARED_TUNNEL_ID" ]; then
        echo "未输入tunnel id，将进行创建"
        read -p "请输入cloudflared tunnel name:" CLOUDFLARED_TUNNEL_ID
        # "如果还是未输入，使用默认值traefik"
        if [ -z "$CLOUDFLARED_TUNNEL_ID" ]; then
            echo "未输入tunnel name，将使用默认值traefik"
            CLOUDFLARED_TUNNEL_ID=traefik
        fi
        cloudflared_tunnel_create ${CLOUDFLARED_TUNNEL_ID}
    fi
else 
    cloudflared_check ${CLOUDFLARED_TUNNEL_ID}
    `dirname $0`/set-args.sh CLOUDFLARED_TUNNEL_ID "$CLOUDFLARED_TUNNEL_ID"
fi

docker rm -f ${container_name} && \
docker run -d --restart=always --name=${container_name} \
--memory=64M \
-e TZ=Asia/Shanghai \
-v ${base_data_dir}/${container_name}/etc:/etc/${container_name} \
--network=${docker_network_name} --network-alias=${container_name}  \
--hostname=${container_name} \
${image} \
--loglevel warn \
--no-tls-verify \
--edge-ip-version auto \
tunnel run --url \
https://traefik:443 \
${CLOUDFLARED_TUNNEL_ID} 