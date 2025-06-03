#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=meilisearch
image=getmeili/meilisearch
port=7700

MEILI_MASTER_KEY=$(`dirname $0`/get-args.sh MEILI_MASTER_KEY MasterKey)
if [ -z "$MEILI_MASTER_KEY" ]; then
    read -p "请输入MasterKey:" MEILI_MASTER_KEY
    if [ -z "$MEILI_MASTER_KEY" ]; then
        echo "随机生成MasterKey"
        MEILI_MASTER_KEY="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
        echo "随机MasterKey为：${MEILI_MASTER_KEY}"
    fi
    `dirname $0`/set-args.sh MEILI_MASTER_KEY "$MEILI_MASTER_KEY"
fi

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-m 256M \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-d --restart=always \
-e MEILI_ENV=development \
-e MEILI_MASTER_KEY=${MEILI_MASTER_KEY} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-p 7700:7700 \
-v /docker_data/meili/data:/meili_data \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
