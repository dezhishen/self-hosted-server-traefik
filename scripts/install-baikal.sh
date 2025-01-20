#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=baikal
image=ckulka/baikal:nginx
port=80

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
# 创建文件夹
mkdir -p ${base_data_dir}/${container_name}/config
mkdir -p ${base_data_dir}/${container_name}/data
mkdir -p ${base_data_dir}/${container_name}/docker-entrypoint
# 如果文件不存，创建docker-entrypoint.d/40-fix-baikal-file-permissions.sh
if [ ! -f "${base_data_dir}/${container_name}/docker-entrypoint/40-fix-baikal-file-permissions.sh" ]; then
  # 创建文件，且不转义变量
  cat > ${base_data_dir}/${container_name}/docker-entrypoint/40-fix-baikal-file-permissions.sh <<EOF
#!/bin/sh
groupmod -o -g \${PGID} www-data
usermod -o -u \${PUID} -g www-data www-data
# Ensure correct file permissions, unless behaviour is explicitly disabled
if [ -z ${BAIKAL_SKIP_CHOWN+x} ]
then
  chown -R www-data:www-data /var/www/baikal
fi
EOF
  chmod +x ${base_data_dir}/${container_name}/docker-entrypoint/40-fix-baikal-file-permissions.sh
fi
docker run --name=${container_name} \
-m 128M \
-d --restart=always \
-e BAIKAL_SERVERNAME=${container_name}.$domain \
-e BAIKAL_SKIP_CHOWN=False \
-e PUID=`id -u` -e PGID=`id -g` \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-v ${base_data_dir}/${container_name}/config:/var/www/baikal/config \
-v ${base_data_dir}/${container_name}/data:/var/www/baikal/Specific \
-v ${base_data_dir}/${container_name}/docker-entrypoint/40-fix-baikal-file-permissions.sh:/docker-entrypoint.d/40-fix-baikal-file-permissions.sh \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}

# 是否安装infcloud
read -p "是否安装infcloud(y/n):" install_infcloud
if [ "$install_infcloud" = "y" ]; then
    echo "暂不支持安装infcloud"
fi
