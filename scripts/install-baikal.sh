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
;;
esac
# 是否安装infcloud
read -p "是否安装infcloud(y/n):" yN
case $yN in
    [Yy]* )
      # 安装 php-fpm
      container_name=infcloud-php
      image=php:7.3-fpm-alpine

      docker pull ${image}
      `dirname $0`/stop-container.sh ${container_name}
      docker run --name=${container_name} \
      --restart=always -d -m 128M \
      -v ${base_data_dir}/${container_name}/nginx:/usr/share/nginx/infcloud:ro \
      ${image}

      # 安装infcloud
      container_name=infcloud
      image=ckulka/infcloud:latest
      port=80
      mkdir -p ${base_data_dir}/${container_name}
      # 如果文件 ${base_data_dir}/${container_name}/config.js 不存在，则下载 
      if [ ! -f "${base_data_dir}/${container_name}/config.js" ]; then
        wget -O ${base_data_dir}/${container_name}/config.js https://raw.githubusercontent.com/ckulka/infcloud-docker/refs/heads/master/examples/config.js
      fi
      docker pull ${image}
      `dirname $0`/stop-container.sh ${container_name}
      docker run --name=${container_name} \
      --restart=always -d -m 128M \
      -e TZ="Asia/Shanghai" \
      --network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
      --link infcloud-php:php \
      -v ${base_data_dir}/${container_name}/nginx:/usr/share/nginx/infcloud \
      -v ${base_data_dir}/${container_name}/config.js:/usr/share/nginx/infcloud/config.js:ro \
      --label "traefik.enable=true" \
      --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
      --label "traefik.http.routers.${container_name}.tls=${tls}" \
      --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
      --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
      --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
      ${image}
    ;;
esac

# read -p "是否安装agendav(y/n):" yN
# case $yN in
#     [Yy]* )
#       container_name=agendav
#       image=ghcr.io/nagimov/agendav-docker:latest
#       port=8080
#       AGENDAV_ENC_KEY=$(`dirname $0`/get-args.sh AGENDAV_ENC_KEY php加密key)
#       if [ -z "$AGENDAV_ENC_KEY" ]; then
#           read -p "请输入php加密key:" AGENDAV_ENC_KEY
#           if [ -z "$AGENDAV_ENC_KEY" ]; then
#               echo "随机生成php加密key"
#               AGENDAV_ENC_KEY=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
#           fi
#           `dirname $0`/set-args.sh AGENDAV_ENC_KEY "$AGENDAV_ENC_KEY"
#       fi
#       docker pull ${image}
#       `dirname $0`/stop-container.sh ${container_name}
#       docker run --name=${container_name} \
#       --restart=always -d -m 128M \
#       -e TZ="Asia/Shanghai" \
#       --network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
#       -e AGENDAV_SERVER_NAME=127.0.0.1 \
#       -e AGENDAV_TITLE="AgendaV" \
#       -e AGENDAV_FOOTER="host by $domain" \
#       -e AGENDAV_ENC_KEY=${AGENDAV_ENC_KEY} \
#       -e AGENDAV_CALDAV_SERVER=http://baikal/cal.php \
#       -e AGENDAV_CALDAV_PUBLIC_URL=https://baikal.$domain \
#       -e AGENDAV_TIMEZONE=Asia/Shanghai \
#       -e AGENDAV_LANG=zh_CN \
#       -e AGENDAV_LOG_DIR=/tmp/ \
#       --label "traefik.enable=true" \
#       --label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
#       --label "traefik.http.routers.${container_name}.tls=${tls}" \
#       --label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
#       --label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
#       --label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
#       ${image}
#     ;;
# esac
