#! /bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4


read -p "是否重装dockerproxy (y/n)" yN
case $yN in
    [Yy]* )
    echo "停止dockerproxy"
    container_name=dockerproxy
    image=tecnativa/docker-socket-proxy
    docker pull ${image}
    docker ps -a -q --filter "name=$container_name" | grep -q . && docker rm -fv $container_name
    docker run \
        --privileged \
        -m 16M --memory-swap 32M \
        -e CONTAINERS=1 \
        -e NETWORKS=1 \
        -e INFO=1 \
        -p 2375:2375 \
        -d --restart=always \
        --network=$docker_network_name --network-alias=dockerproxy \
        --name dockerproxy \
        -v /var/run/docker.sock:/var/run/docker.sock \
        tecnativa/docker-socket-proxy
    ;;
esac
read -p "是否重装 traefik (y/n)" yN
case $yN in
    [Yy]* )
    container_name=traefik
    nip_enabled="false"
    TRAEFIK_AUTH_USER=$(`dirname $0`/get-args.sh TRAEFIK_AUTH_USER 用户名)
    if [ -z "$TRAEFIK_AUTH_USER" ]; then
        read -p "请输入用户名:" TRAEFIK_AUTH_USER
        if [ -z "$TRAEFIK_AUTH_USER" ]; then
            echo "用户名使用默认值: admin"
            TRAEFIK_AUTH_USER="admin"
        fi
        `dirname $0`/set-args.sh TRAEFIK_AUTH_USER "$TRAEFIK_AUTH_USER"
    fi

    TRAEFIK_AUTH_PASSWORD=$(`dirname $0`/get-args.sh TRAEFIK_AUTH_PASSWORD 密码)
    if [ -z "$TRAEFIK_AUTH_PASSWORD" ]; then
        read -p "请输入密码:" TRAEFIK_AUTH_PASSWORD
        if [ -z "$TRAEFIK_AUTH_PASSWORD" ]; then
            echo "随机生成密码"
            TRAEFIK_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
        fi
        `dirname $0`/set-args.sh TRAEFIK_AUTH_PASSWORD "$TRAEFIK_AUTH_PASSWORD"
    fi

    echo "用户名: $TRAEFIK_AUTH_USER"
    echo "密码: $TRAEFIK_AUTH_PASSWORD"
    digest="$(printf "%s:%s:%s" "$TRAEFIK_AUTH_USER" "traefik" "$TRAEFIK_AUTH_PASSWORD" | md5sum | awk '{print $1}' )"
    userlist=$(printf "%s:%s:%s\n" "$TRAEFIK_AUTH_USER" "traefik" "$digest")
    if [ "$tls" = "true" ]; then
        # 检查domain结尾是否是nip.io
        echo "检查domain结尾是否是nip.io"
        if echo "$domain" | grep -q -E '\.nip.io$'
        then
            nip_enabled="true"
            echo "使用nip.io域名"
        else
            echo "使用nip.io域名，跳过cf配置"
            nip_enabled="false"
            acme_email=$(`dirname $0`/get-args.sh acme_email acme的email)
            if [ -z "$acme_email" ]; then
                read -p "请输入acme的email: " acme_email
                if [ -z "$acme_email" ]; then
                    echo "acme的email不能为空"
                    exit 1
                fi
                `dirname $0`/set-args.sh acme_email $acme_email
            fi
            CF_API_EMAIL=$(`dirname $0`/get-args.sh CF_API_EMAIL Cloudflare的邮箱)
            if [ -z "$CF_API_EMAIL" ]; then
                read -p "请输入Cloudflare的邮箱:" CF_API_EMAIL
                if [ -z "$CF_API_EMAIL" ]; then
                    echo "Cloudflare的邮箱不能为空"
                    exit 1
                fi
                `dirname $0`/set-args.sh CF_API_EMAIL "$CF_API_EMAIL"
            fi
            CF_DNS_API_TOKEN=$(`dirname $0`/get-args.sh CF_DNS_API_TOKEN Cloudflare的api令牌)
            if [ -z "$CF_DNS_API_TOKEN" ]; then
                read -p "请输入Cloudflare的api令牌:" CF_DNS_API_TOKEN
                if [ -z "$CF_DNS_API_TOKEN" ]; then
                    echo "Cloudflare的api令牌不能为空"
                    exit 1
                fi
                `dirname $0`/set-args.sh CF_DNS_API_TOKEN "$CF_DNS_API_TOKEN"
            fi
        fi
    fi
    echo "停止之前的traefik容器"
    container_name=traefik
    image=traefik
    docker pull ${image}
    docker ps -a -q --filter "name=$container_name" | grep -q . && docker rm -fv $container_name
    echo "启动traefik容器" && \
    docker run --name=traefik \
    --restart=always -d -m 128M \
    -e TZ="Asia/Shanghai" \
    -e LANG="zh_CN.UTF-8" \
    -p 80:80 -p 80:80/udp \
    `if [ "$tls" = "true" ]; then echo  "-p 443:443/udp -p 443:443"; fi` \
    -e UID=`id -u` \
    -e GID=`id -g` \
    `if [ "$tls" = "true" ]; then \
        if [ "nip_enabeld" = "false" ];
        then \
            echo "-e \"CF_API_EMAIL=${CF_API_EMAIL}\" -e \"CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}\""; \
        else \
            echo ""; \
        fi \
    fi `\
    --network=$docker_network_name --network-alias=traefik \
    --label 'traefik.http.routers.traefik.rule=Host(`traefik'.$domain'`)' \
    --label "traefik.http.routers.traefik.tls=${tls}" \
    --label "traefik.http.routers.traefik.service=traefik" \
    --label "traefik.http.routers.traefik.tls.certresolver=traefik" \
    --label "traefik.http.routers.traefik.tls.domains[0].main=*.$domain" \
    --label "traefik.http.services.traefik.loadbalancer.server.port=8080" \
    --label "traefik.http.middlewares.traefik-auth.digestauth.users=$userlist" \
    --label "traefik.http.routers.traefik.middlewares=traefik-auth@docker" \
    --label "traefik.enable=true" \
    -v $base_data_dir/traefik/acme:/acme \
    -v $base_data_dir/traefik/config/providers:/config/providers \
    ${image} \
    --log.level=INFO \
    --api \
    --api.dashboard=true \
    --api.insecure=true \
    --providers.docker=true \
    --providers.docker.endpoint=tcp://dockerproxy:2375 \
    --providers.docker.network=$docker_network_name \
    --providers.docker.exposedbydefault=false \
    --entrypoints.web.address=":80" \
    `if [ "$tls" = "true" ]; then \
    echo """ \
    --entrypoints.websecure.address=":443" \
    --entrypoints.web.http.redirections.entryPoint.to=websecure \
    --entrypoints.web.http.redirections.entryPoint.scheme=https \
    """ \
    fi` \
    `if [ "$tls" = "true" ]; then \
        if [ "nip_enabeld" = "false" ]; then \
        echo """ \
            --certificatesresolvers.traefik.acme.dnschallenge=true \
            --certificatesresolvers.traefik.acme.dnschallenge.provider=cloudflare \
            --certificatesResolvers.traefik.acme.dnsChallenge.delayBeforeCheck=10 \
            --certificatesResolvers.traefik.acme.dnsChallenge.resolvers="1.1.1.1:53,8.8.8.8:53" \
            --certificatesresolvers.traefik.acme.email=$acme_email \
            --certificatesresolvers.traefik.acme.storage=/acme/acme.json \
            """ \
        else \
            echo """ \
            --certificatesresolvers.traefik=false \
            """ \
        fi \
    fi` \
    --providers.file.directory=/config/providers \
    --global.sendAnonymousUsage \
    --serverstransport.insecureskipverify=true \
    --experimental.plugins.cloudflarewarp.modulename=github.com/BetterCorp/cloudflarewarp \
    --experimental.plugins.cloudflarewarp.version=v1.3.3
    ;;
esac
