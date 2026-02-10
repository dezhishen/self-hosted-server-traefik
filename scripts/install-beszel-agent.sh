# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=beszel-agent
image=henrygd/beszel-agent
port=45876

docker pull $image

`dirname $0`/stop-container.sh ${container_name}
echo "尝试从beszel容器获取公钥"
path=${base_data_dir}/beszel/data/id_ed25519.pub
if [ -f "$path" ]; then
    public_key=$(cat $path)
    echo "获取到公钥: ${public_key}"
fi
if [ -z "$public_key" ]; then
    read -p "未获取到公钥，请从beszel容器内的/beszel_data/id_ed25519.pub文件中获取公钥，并输入：" public_key
    if [ -z "$public_key" ]; then
        echo "公钥不能为空，退出"
        exit 1
    fi
fi
docker run -d --name=${container_name} \
--restart=always \
--network=$docker_network_name \
--network-alias=${container_name} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e PORT=45876 \
-e KEY="$public_key" \
-m 64M \
-v /var/run/docker.sock:/var/run/docker.sock:ro \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
--label "traefik.enable=true" \
$image
