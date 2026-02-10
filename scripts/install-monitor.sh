#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4

read -p "是否重装 Grafana (y/n)" yN
case $yN in
    [Yy]* )
    container=grafana
    image="grafana/grafana"
    port=3000
    if $tls = "true" ; then
	scheme="https"
	gf_root_url="https://$container.$domain"
    else
	scheme="http"
        gf_root_url="http://$container.$domain"
    fi
    docker pull $image
    `dirname $0`/stop-container.sh $container
    docker run -d --restart unless-stopped \
    --user $(id -u):$(id -g) \
    -e TZ="Asia/Shanghai" \
    -e GF_SERVER_ROOT_URL="${gf_root_url}" \
    -e LANG="zh_CN.UTF-8" \
    -m 64M \
    --network=$docker_network_name --network-alias=$container --hostname=$container \
    -v $base_data_dir/${container}:/var/lib/grafana \
    --name $container \
    --label 'traefik.http.routers.'$container'.rule=Host(`'$container.$domain'`)' \
    --label "traefik.http.routers.$container.tls=${tls}" \
    --label "traefik.http.routers.$container.tls.certresolver=traefik" \
    --label "traefik.http.routers.$container.tls.domains[0].main=$container.$domain" \
    --label "traefik.http.services.$container.loadbalancer.server.port=${port}" \
    --label "traefik.enable=true" \
    --label "traefik.http.middlewares.allow-embed.headers.customresponseheaders.X-Frame-Options=" \
    --label "traefik.http.middlewares.allow-embed.headers.customresponseheaders.Content-Security-Policy=frame-ancestors 'self' ${scheme}://${domain} ${scheme}://*.${domain}" \
    --label "traefik.http.routers.${container}.middlewares=allow-embed@docker" \
    $image
    ;;
esac

read -p "是否重装 Prometheus (y/n)" yN
case $yN in
    [Yy]* )
    container=prometheus
    image="prom/prometheus"
    port=9090
    docker pull $image
    
    `dirname $0`/stop-container.sh $container
    docker run -d --restart unless-stopped \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    --user $(id -u):$(id -g) -m 64M \
    --network=$docker_network_name --network-alias=$container --hostname=$container \
    -v $base_data_dir/${container}/tsdb:/prometheus \
    -v $base_data_dir/${container}/config:/etc/prometheus \
    --name $container \
    --label 'traefik.http.routers.'$container'.rule=Host(`'$container.$domain'`)' \
    --label "traefik.http.routers.$container.tls=${tls}" \
    --label "traefik.http.routers.$container.tls.certresolver=traefik" \
    --label "traefik.http.routers.$container.tls.domains[0].main=$container.$domain" \
    --label "traefik.http.services.$container.loadbalancer.server.port=${port}" \
    --label "traefik.http.middlewares.allow-embed.headers.customresponseheaders.X-Frame-Options=" \
    --label "traefik.http.middlewares.allow-embed.headers.customresponseheaders.Content-Security-Policy=frame-ancestors 'self' https://${domain} https://*.${domain}" \
    --label "traefik.http.routers.${container}.middlewares=allow-embed@docker"
    --label "traefik.enable=false" \
    $image
    ;;
esac

