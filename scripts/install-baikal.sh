#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
read -p "是否重装baikal(y/n):" yN
case $yN in
    [Yy]* )
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
groupmod -o -g \${PGID} nginx
usermod -o -u \${PUID} -g nginx nginx
# Ensure correct file permissions, unless behaviour is explicitly disabled
if [ -z \${BAIKAL_SKIP_CHOWN+x} ]
then
  chown -R nginx:nginx /var/www/baikal
fi
EOF
  chmod +x ${base_data_dir}/${container_name}/docker-entrypoint/40-fix-baikal-file-permissions.sh
fi
# 检查Plugin.php是否存在
if [ ! -f "${base_data_dir}/${container_name}/Plugin.php" ]; then
  # 下载文件
  wget -O ${base_data_dir}/${container_name}/Plugin.php https://raw.githubusercontent.com/dezhishen/self-hosted-server-traefik/master/patch/Plugin.php
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
-v ${base_data_dir}/${container_name}/Plugin.php:/var/www/baikal/vendor/sabre/dav/lib/CalDAV/Plugin.php \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
;;
esac
