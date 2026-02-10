# !/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
pre=xiaozhi-esp32


read -p "是否部署核心服务 y/n (默认n): " deploy_core
case $deploy_core in
    y|Y ) 
        # container_name=xiaozhi-esp32-server
        app=server
        container_name=${pre}-${app}
        image=ghcr.nju.edu.cn/xinnan-tech/xiaozhi-esp32-server:${app}_latest
        docker pull $image
        port1=8000
        port2=8003
        echo "部署核心服务"
        `dirname $0`/stop-container.sh ${container_name} 
        docker run -d --name=${container_name} \
        --restart=always \
        --network=$docker_network_name \
        --network-alias=${container_name} \
        --hostname=${container_name} \
        -e TZ="Asia/Shanghai" \
        -e LANG="zh_CN.UTF-8" \
        -p ${port2}:${port2} \
        -p ${port1}:${port1} \
        -p 8006:8006 \
        -v ${base_data_dir}/${pre}/data:/opt/xiaozhi-esp32-server/data \
        -v ${base_data_dir}/${pre}/models/SenseVoiceSmall/model.pt:/opt/xiaozhi-esp32-server/models/SenseVoiceSmall/model.pt \
        -v ${base_data_dir}/${pre}/tmp:/opt/xiaozhi-esp32-server/tmp \
        --label 'traefik.http.routers.'${pre}'-ws.rule=Host(`'${pre}-ws.${domain}'`)' \
        --label "traefik.http.routers.${pre}-ws.tls=${tls}" \
        --label "traefik.http.routers.${pre}-ws.tls.certresolver=traefik" \
        --label "traefik.http.routers.${pre}-ws.tls.domains[0].main=${pre}-ws.${domain}" \
        --label "traefik.http.routers.${pre}-ws.service=${pre}-ws" \
        --label "traefik.http.services.${pre}-ws.loadbalancer.server.port=${port1}" \
        --label 'traefik.http.routers.'${pre}'.rule=Host(`'${pre}.${domain}'`)' \
        --label "traefik.http.routers.${pre}.tls=${tls}" \
        --label "traefik.http.routers.${pre}.tls.certresolver=traefik" \
        --label "traefik.http.routers.${pre}.tls.domains[0].main=${pre}.${domain}" \
        --label "traefik.http.routers.${pre}.service=${pre}" \
        --label "traefik.http.services.${pre}.loadbalancer.server.port=${port2}" \
        --label "traefik.enable=true" \
        $image
        ;;
esac
read -p "是否部署智控台服务 y/n (默认n): " deploy_web
case $deploy_web in
    y|Y )
        echo "部署智控台服务"
        app=web
        container_name=${pre}-${app}
        MYSQL_HOST=$(`dirname $0`/get-args.sh MYSQL_HOST "mysql主机" )
        if [ -z "$MYSQL_HOST" ]; then
            read -p "请输入mysql主机:" MYSQL_HOST
            if [ -z "$MYSQL_HOST" ]; then
                echo "mysql主机为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_HOST "$MYSQL_HOST"
        fi
        MYSQL_PORT=$(`dirname $0`/get-args.sh MYSQL_PORT "mysql端口" )
        if [ -z "$MYSQL_PORT" ]; then
            read -p "请输入mysql端口:" MYSQL_PORT
            if [ -z "$MYSQL_PORT" ]; then
                echo "mysql端口为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_PORT "$MYSQL_PORT"
        fi
        MYSQL_USER=$(`dirname $0`/get-args.sh MYSQL_USER "mysql用户名" )
        if [ -z "$MYSQL_USER" ]; then
            read -p "请输入mysql用户名:" MYSQL_USER
            if [ -z "$MYSQL_USER" ]; then
                echo "mysql用户名为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_USER "$MYSQL_USER"
        fi
        MYSQL_PASSWORD=$(`dirname $0`/get-args.sh MYSQL_PASSWORD "mysql密码" )
        if [ -z "$MYSQL_PASSWORD" ]; then
            read -p "请输入mysql密码:" MYSQL_PASSWORD
            if [ -z "$MYSQL_PASSWORD" ]; then
                echo "mysql密码为空，退出"
                exit 1
            fi
            `dirname $0`/set-args.sh MYSQL_PASSWORD "$MYSQL_PASSWORD"
        fi
        MYSQL_DB_NAME=${pre}
        if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$MYSQL_DB_NAME" ] || [ -z "$MYSQL_USER" ]; then
            echo "未输入mysql主机、密码、数据库名或用户名，退出安装。"
            exit 1
        fi
        database_url="mysql://$MYSQL_USER:$MYSQL_PASSWORD@$MYSQL_HOST:$MYSQL_PORT/$MYSQL_DB_NAME"
        # 获取redis信息
        REDIS_HOST=$(`dirname $0`/get-args.sh REDIS_HOST "redis的host")
        if [ -z "$REDIS_HOST" ]; then
            read -p "请输入redis的host:" REDIS_HOST
            if [ -z "$REDIS_HOST" ]; then
                echo "未输入redis的host，将退出"
                exit 1
            fi
        fi
        REDIS_PORT=$(`dirname $0`/get-args.sh REDIS_PORT "redis的port")
        if [ -z "$REDIS_PORT" ]; then
            read -p "请输入redis的port:" REDIS_PORT
            if [ -z "$REDIS_PORT" ]; then
                echo "未输入redis的port，将使用默认值6379"
                REDIS_PORT=6379
            fi
        fi
        REDIS_PASSWORD_SET=$(`dirname $0`/get-args.sh REDIS_PASSWORD_SET "是否设置了Redis密码")
        if [ $REDIS_PASSWORD_SET = "y" ]; then 
            REDIS_PASSWORD=$(`dirname $0`/get-args.sh REDIS_PASSWORD "Redis密码")
        fi
        XIAOZHI_ESP32_REDIS_DBINDEX=$(`dirname $0`/get-args.sh XIAOZHI_ESP32_REDIS_DBINDEX "请输入xiaozhi使用的redis db")
        if [ -z "$XIAOZHI_ESP32_REDIS_DBINDEX" ]; then
            read -p "请输入immich使用的redis db:" XIAOZHI_ESP32_REDIS_DBINDEX
            if [ -z "$XIAOZHI_ESP32_REDIS_DBINDEX" ]; then
                echo "未输入redis的db，将使用默认值3"
                XIAOZHI_ESP32_REDIS_DBINDEX=3
            fi
            `dirname $0`/set-args.sh XIAOZHI_ESP32_REDIS_DBINDEX ${XIAOZHI_ESP32_REDIS_DBINDEX}
        fi
        image=ghcr.nju.edu.cn/xinnan-tech/xiaozhi-esp32-server:${app}_latest
        port=8002
        docker pull $image
        `dirname $0`/stop-container.sh ${container_name} 
        docker run -d --name=${container_name} \
        --restart=always \
        --network=$docker_network_name \
        --network-alias=${container_name} \
        --hostname=${container_name} \
        `#--user $(id -u):$(id -g)` \
        -e TZ="Asia/Shanghai" \
        -e SPRING_DATASOURCE_DRUID_URL="jdbc:${database_url}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&nullCatalogMeansCurrent=true&connectTimeout=30000&socketTimeout=30000&autoReconnect=true&failOverReadOnly=false&maxReconnects=10" \
        -e SPRING_DATASOURCE_DRUID_USERNAME="${MYSQL_USER}" \
        -e SPRING_DATASOURCE_DRUID_PASSWORD="${MYSQL_PASSWORD}" \
        -e SPRING_DATA_REDIS_HOST="${REDIS_HOST}" \
        -e SPRING_DATA_REDIS_PASSWORD="${REDIS_PASSWORD}" \
        -e SPRING_DATA_REDIS_PORT="${REDIS_PORT}" \
        -e SPRING_DATA_REDIS_DATABASE="${XIAOZHI_ESP32_REDIS_DBINDEX}" \
        -e LANG="zh_CN.UTF-8" \
        -v ${base_data_dir}/${pre}/uploadfile:/uploadfile \
        --label 'traefik.http.routers.'${pre}'-web.rule=Host(`'${pre}-web.${domain}'`)' \
        --label "traefik.http.routers.${pre}-web.tls=${tls}" \
        --label "traefik.http.routers.${pre}-web.tls.certresolver=traefik" \
        --label "traefik.http.routers.${pre}-web.tls.domains[0].main=${pre}-web.${domain}" \
        --label "traefik.http.services.${pre}-web.loadbalancer.server.port=${port}" \
        --label "traefik.enable=true" \
        $image
        ;;
esac

read -p "是否需要重新部署声纹识别服务 y/n (默认n): " deploy_svr
case $deploy_svr in
    y|Y )
        container_name="voiceprint-api"
        image="ghcr.nju.edu.cn/xinnan-tech/voiceprint-api:latest"
        docker pull $image
        port=8005
        `dirname $0`/stop-container.sh ${container_name}
        docker run -d --name=${container_name} \
          --restart=always \
          --network=$docker_network_name \
          --network-alias=${container_name} \
          --hostname=${container_name} \
          -e TZ="Asia/Shanghai" \
          -e LANG="zh_CN.UTF-8" \
          -v ${base_data_dir}/${pre}/voiceprint-api/data:/app/data \
          --security-opt seccomp:unconfined \
          --device /dev/dri \
          --label 'traefik.http.routers.voiceprint-api.rule=Host(`voiceprint-api.'${domain}'`)' \
          --label "traefik.http.routers.voiceprint-api.tls=${tls}" \
          --label "traefik.http.routers.voiceprint-api.tls.certresolver=traefik" \
          --label "traefik.http.routers.voiceprint-api.tls.domains[0].main=voiceprint-api.${domain}" \
          --label "traefik.http.services.voiceprint-api.loadbalancer.server.port=${port}" \
          --label "traefik.enable=false" \
        $image
        ;;
esac


# mcp接入点
read -p "是否部署MCP接入点 y/n (默认n): " deploy_mcp
case $deploy_mcp in
    y|Y )
        echo "部署MCP接入点服务"
        app=mcp
        container_name=${pre}-${app}
        image=ghcr.nju.edu.cn/xinnan-tech/mcp-endpoint-server:latest
        docker pull $image
        port=8004
        `dirname $0`/stop-container.sh ${container_name} 
        docker run -d --name=${container_name} \
            --restart=always \
            --network=$docker_network_name \
            --network-alias=${container_name} \
            --hostname=${container_name} \
            -e TZ="Asia/Shanghai" \
            -e LANG="zh_CN.UTF-8" \
            --security-opt seccomp:unconfined \
            --device /dev/dri \
            -p ${port}:${port} \
	    -v ${base_data_dir}/${pre}/${app}/data:/opt/mcp-endpoint-server/data \
            --label 'traefik.http.routers.'${pre}-${app}'.rule=Host(`'${pre}-${app}.${domain}'`)' \
            --label "traefik.http.routers.${pre}-${app}.tls=${tls}" \
            --label "traefik.http.routers.${pre}-${app}.tls.certresolver=traefik" \
            --label "traefik.http.routers.${pre}-${app}.tls.domains[0].main=${pre}-${app}.${domain}" \
            --label "traefik.http.routers.${pre}-${app}.service=${pre}-${app}" \
            --label "traefik.http.services.${pre}-${app}.loadbalancer.server.port=${port}" \
            --label "traefik.enable=true" \
        $image
    ;;
esac
