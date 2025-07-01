#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=openlist-api
image=openlistteam/openlist_api_server:latest 
port=3000

OPLIST_ONEDRIVE_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_ONEDRIVE_BUILDIN "是否提供onedrive的凭据[Y/N]")
if [ -z "$OPLIST_ONEDRIVE_BUILDIN" ]; then
    read -p "是否提供onedrive的凭据[Y/N]:" OPLIST_ONEDRIVE_BUILDIN
    if [ -z "$OPLIST_ONEDRIVE_BUILDIN" ]; then
        echo "是否提供onedrive的凭据为空,使用默认值 N"
        OPLIST_ONEDRIVE_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_ONEDRIVE_BUILDIN "$OPLIST_ONEDRIVE_BUILDIN"
fi
if [ "$OPLIST_ONEDRIVE_BUILDIN" = "Y" ]; then
    OPLIST_ONEDRIVE_UID=$(`dirname $0`/get-args.sh OPLIST_ONEDRIVE_UID "Onedrive的UID")
    if [ -z "$OPLIST_ONEDRIVE_UID" ]; then
        read -p "Onedrive的UID:" OPLIST_ONEDRIVE_UID
        if [ -z "$OPLIST_ONEDRIVE_UID" ]; then
            echo "Onedrive的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_ONEDRIVE_UID "$OPLIST_ONEDRIVE_UID"
    fi
    OPLIST_ONEDRIVE_KEY=$(`dirname $0`/get-args.sh OPLIST_ONEDRIVE_KEY "Onedrive的KEY")
    if [ -z "$OPLIST_ONEDRIVE_KEY" ]; then
        read -p "Onedrive的KEY:" OPLIST_ONEDRIVE_KEY
        if [ -z "$OPLIST_ONEDRIVE_KEY" ]; then
            echo "Onedrive的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_ONEDRIVE_KEY "$OPLIST_ONEDRIVE_KEY"
    fi
fi

OPLIST_ALICLOUD_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_ALICLOUD_BUILDIN "是否提供阿里云盘的凭据[Y/N]")
if [ -z "$OPLIST_ALICLOUD_BUILDIN" ]; then
    read -p "是否提供阿里云盘的凭据[Y/N]:" OPLIST_ALICLOUD_BUILDIN
    if [ -z "$OPLIST_ALICLOUD_BUILDIN" ]; then
        echo "是否提供阿里云盘的凭据为空,使用默认值 N"
        OPLIST_ALICLOUD_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_ALICLOUD_BUILDIN "$OPLIST_ALICLOUD_BUILDIN"
fi
if [ "$OPLIST_ALICLOUD_BUILDIN" = "Y" ]; then
    OPLIST_ALICLOUD_UID=$(`dirname $0`/get-args.sh OPLIST_ALICLOUD_UID "阿里云盘的UID")
    if [ -z "$OPLIST_ALICLOUD_UID" ]; then
        read -p "阿里云盘的UID:" OPLIST_ALICLOUD_UID
        if [ -z "$OPLIST_ALICLOUD_UID" ]; then
            echo "阿里云盘的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_ALICLOUD_UID "$OPLIST_ALICLOUD_UID"
    fi
    OPLIST_ALICLOUD_KEY=$(`dirname $0`/get-args.sh OPLIST_ALICLOUD_KEY "阿里云盘的KEY")
    if [ -z "$OPLIST_ALICLOUD_KEY" ]; then
        read -p "阿里云盘的KEY:" OPLIST_ALICLOUD_KEY
        if [ -z "$OPLIST_ALICLOUD_KEY" ]; then
            echo "阿里云盘的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_ALICLOUD_KEY "$OPLIST_ALICLOUD_KEY"
    fi
fi
OPLIST_BAIDUYUN_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_BAIDUYUN_BUILDIN "是否提供百度网盘的凭据[Y/N]")
if [ -z "$OPLIST_BAIDUYUN_BUILDIN" ]; then
    read -p "是否提供百度网盘的凭据[Y/N]:" OPLIST_BAIDUYUN_BUILDIN
    if [ -z "$OPLIST_BAIDUYUN_BUILDIN" ]; then
        echo "是否提供百度网盘的凭据为空,使用默认值 N"
        OPLIST_BAIDUYUN_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_BAIDUYUN_BUILDIN "$OPLIST_BAIDUYUN_BUILDIN"
fi
if [ "$OPLIST_BAIDUYUN_BUILDIN" = "Y" ]; then
    OPLIST_BAIDUYUN_UID=$(`dirname $0`/get-args.sh OPLIST_BAIDUYUN_UID "百度网盘的UID")
    if [ -z "$OPLIST_BAIDUYUN_UID" ]; then
        read -p "百度网盘的UID:" OPLIST_BAIDUYUN_UID
        if [ -z "$OPLIST_BAIDUYUN_UID" ]; then
            echo "百度网盘的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_BAIDUYUN_UID "$OPLIST_BAIDUYUN_UID"
    fi
    OPLIST_BAIDUYUN_KEY=$(`dirname $0`/get-args.sh OPLIST_BAIDUYUN_KEY "百度网盘的KEY")
    if [ -z "$OPLIST_BAIDUYUN_KEY" ]; then
        read -p "百度网盘的KEY:" OPLIST_BAIDUYUN_KEY
        if [ -z "$OPLIST_BAIDUYUN_KEY" ]; then
            echo "百度网盘的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_BAIDUYUN_KEY "$OPLIST_BAIDUYUN_KEY"
    fi
fi
OPLIST_CLOUD115_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_CLOUD115_BUILDIN "是否提供云盘115的凭据[Y/N]")
if [ -z "$OPLIST_CLOUD115_BUILDIN" ]; then
    read -p "是否提供云盘115的凭据[Y/N]:" OPLIST_CLOUD115_BUILDIN
    if [ -z "$OPLIST_CLOUD115_BUILDIN" ]; then
        echo "是否提供云盘115的凭据为空,使用默认值 N"
        OPLIST_CLOUD115_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_CLOUD115_BUILDIN "$OPLIST_CLOUD115_BUILDIN"
fi
if [ "$OPLIST_CLOUD115_BUILDIN" = "Y" ]; then
    OPLIST_CLOUD115_UID=$(`dirname $0`/get-args.sh OPLIST_CLOUD115_UID "云盘115的UID")
    if [ -z "$OPLIST_CLOUD115_UID" ]; then
        read -p "云盘115的UID:" OPLIST_CLOUD115_UID
        if [ -z "$OPLIST_CLOUD115_UID" ]; then
            echo "云盘115的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_CLOUD115_UID "$OPLIST_CLOUD115_UID"
    fi
    OPLIST_CLOUD115_KEY=$(`dirname $0`/get-args.sh OPLIST_CLOUD115_KEY "云盘115的KEY")
    if [ -z "$OPLIST_CLOUD115_KEY" ]; then
        read -p "云盘115的KEY:" OPLIST_CLOUD115_KEY
        if [ -z "$OPLIST_CLOUD115_KEY" ]; then
            echo "云盘115的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_CLOUD115_KEY "$OPLIST_CLOUD115_KEY"
    fi
fi
OPLIST_GOOGLEUI_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_GOOGLEUI_BUILDIN "是否提供谷歌网盘的凭据[Y/N]")
if [ -z "$OPLIST_GOOGLEUI_BUILDIN" ]; then
    read -p "是否提供谷歌网盘的凭据[Y/N]:" OPLIST_GOOGLEUI_BUILDIN
    if [ -z "$OPLIST_GOOGLEUI_BUILDIN" ]; then
        echo "是否提供谷歌网盘的凭据为空,使用默认值 N"
        OPLIST_GOOGLEUI_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_GOOGLEUI_BUILDIN "$OPLIST_GOOGLEUI_BUILDIN"
fi
if [ "$OPLIST_GOOGLEUI_BUILDIN" = "Y" ]; then
    OPLIST_GOOGLEUI_UID=$(`dirname $0`/get-args.sh OPLIST_GOOGLEUI_UID "谷歌网盘的UID")
    if [ -z "$OPLIST_GOOGLEUI_UID" ]; then
        read -p "谷歌网盘的UID:" OPLIST_GOOGLEUI_UID
        if [ -z "$OPLIST_GOOGLEUI_UID" ]; then
            echo "谷歌网盘的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_GOOGLEUI_UID "$OPLIST_GOOGLEUI_UID"
    fi
    OPLIST_GOOGLEUI_KEY=$(`dirname $0`/get-args.sh OPLIST_GOOGLEUI_KEY "谷歌网盘的KEY")
    if [ -z "$OPLIST_GOOGLEUI_KEY" ]; then
        read -p "谷歌网盘的KEY:" OPLIST_GOOGLEUI_KEY
        if [ -z "$OPLIST_GOOGLEUI_KEY" ]; then
            echo "谷歌网盘的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_GOOGLEUI_KEY "$OPLIST_GOOGLEUI_KEY"
    fi
fi
OPLIST_YANDEXUI_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_YANDEXUI_BUILDIN "是否提供Yandex网盘的凭据[Y/N]")
if [ -z "$OPLIST_YANDEXUI_BUILDIN" ]; then
    read -p "是否提供Yandex网盘的凭据[Y/N]:" OPLIST_YANDEXUI_BUILDIN
    if [ -z "$OPLIST_YANDEXUI_BUILDIN" ]; then
        echo "是否提供Yandex网盘的凭据为空,使用默认值 N"
        OPLIST_YANDEXUI_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_YANDEXUI_BUILDIN "$OPLIST_YANDEXUI_BUILDIN"
fi
if [ "$OPLIST_YANDEXUI_BUILDIN" = "Y" ]; then
    OPLIST_YANDEXUI_UID=$(`dirname $0`/get-args.sh OPLIST_YANDEXUI_UID "Yandex网盘的UID")
    if [ -z "$OPLIST_YANDEXUI_UID" ]; then
        read -p "Yandex网盘的UID:" OPLIST_YANDEXUI_UID
        if [ -z "$OPLIST_YANDEXUI_UID" ]; then
            echo "Yandex网盘的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_YANDEXUI_UID "$OPLIST_YANDEXUI_UID"
    fi
    OPLIST_YANDEXUI_KEY=$(`dirname $0`/get-args.sh OPLIST_YANDEXUI_KEY "Yandex网盘的KEY")
    if [ -z "$OPLIST_YANDEXUI_KEY" ]; then
        read -p "Yandex网盘的KEY:" OPLIST_YANDEXUI_KEY
        if [ -z "$OPLIST_YANDEXUI_KEY" ]; then
            echo "Yandex网盘的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_YANDEXUI_KEY "$OPLIST_YANDEXUI_KEY"
    fi
fi
OPLIST_DROPBOXS_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_DROPBOXS_BUILDIN "是否提供Dropbox的凭据[Y/N]")
if [ -z "$OPLIST_DROPBOXS_BUILDIN" ]; then
    read -p "是否提供Dropbox的凭据[Y/N]:" OPLIST_DROPBOXS_BUILDIN
    if [ -z "$OPLIST_DROPBOXS_BUILDIN" ]; then
        echo "是否提供Dropbox的凭据为空,使用默认值 N"
        OPLIST_DROPBOXS_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_DROPBOXS_BUILDIN "$OPLIST_DROPBOXS_BUILDIN"
fi
if [ "$OPLIST_DROPBOXS_BUILDIN" = "Y" ]; then
    OPLIST_DROPBOXS_UID=$(`dirname $0`/get-args.sh OPLIST_DROPBOXS_UID "Dropbox的UID")
    if [ -z "$OPLIST_DROPBOXS_UID" ]; then
        read -p "Dropbox的UID:" OPLIST_DROPBOXS_UID
        if [ -z "$OPLIST_DROPBOXS_UID" ]; then
            echo "Dropbox的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_DROPBOXS_UID "$OPLIST_DROPBOXS_UID"
    fi
    OPLIST_DROPBOXS_KEY=$(`dirname $0`/get-args.sh OPLIST_DROPBOXS_KEY "Dropbox的KEY")
    if [ -z "$OPLIST_DROPBOXS_KEY" ]; then
        read -p "Dropbox的KEY:" OPLIST_DROPBOXS_KEY
        if [ -z "$OPLIST_DROPBOXS_KEY" ]; then
            echo "Dropbox的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_DROPBOXS_KEY "$OPLIST_DROPBOXS_KEY"
    fi
fi
OPLIST_QUARKPAN_BUILDIN=$(`dirname $0`/get-args.sh OPLIST_QUARKPAN_BUILDIN "是否提供夸克网盘的凭据[Y/N]")
if [ -z "$OPLIST_QUARKPAN_BUILDIN" ]; then
    read -p "是否提供夸克网盘的凭据[Y/N]:" OPLIST_QUARKPAN_BUILDIN
    if [ -z "$OPLIST_QUARKPAN_BUILDIN" ]; then
        echo "是否提供夸克网盘的凭据为空,使用默认值 N"
        OPLIST_QUARKPAN_BUILDIN=N
    fi
    `dirname $0`/set-args.sh OPLIST_QUARKPAN_BUILDIN "$OPLIST_QUARKPAN_BUILDIN"
fi
if [ "$OPLIST_QUARKPAN_BUILDIN" = "Y" ]; then
    OPLIST_QUARKPAN_UID=$(`dirname $0`/get-args.sh OPLIST_QUARKPAN_UID "夸克网盘的UID")
    if [ -z "$OPLIST_QUARKPAN_UID" ]; then
        read -p "夸克网盘的UID:" OPLIST_QUARKPAN_UID
        if [ -z "$OPLIST_QUARKPAN_UID" ]; then
            echo "夸克网盘的UID为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_QUARKPAN_UID "$OPLIST_QUARKPAN_UID"
    fi
    OPLIST_QUARKPAN_KEY=$(`dirname $0`/get-args.sh OPLIST_QUARKPAN_KEY "夸克网盘的KEY")
    if [ -z "$OPLIST_QUARKPAN_KEY" ]; then
        read -p "夸克网盘的KEY:" OPLIST_QUARKPAN_KEY
        if [ -z "$OPLIST_QUARKPAN_KEY" ]; then
            echo "夸克网盘的KEY为空,请检查"
            exit 1
        fi
        `dirname $0`/set-args.sh OPLIST_QUARKPAN_KEY "$OPLIST_QUARKPAN_KEY"
    fi
fi

docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-m 128M \
-d --restart=always \
-e OPLIST_MAIN_URLS="${container_name}.${domain}" \
-e OPLIST_ONEDRIVE_UID=${OPLIST_ONEDRIVE_UID} \
-e OPLIST_ONEDRIVE_KEY=${OPLIST_ONEDRIVE_UID} \
-e OPLIST_ALICLOUD_UID=${OPLIST_ALICLOUD_UID} \
-e OPLIST_ALICLOUD_KEY=${OPLIST_ALICLOUD_KEY} \
-e OPLIST_BAIDUYUN_UID=${OPLIST_BAIDUYUN_UID} \
-e OPLIST_BAIDUYUN_KEY=${OPLIST_BAIDUYUN_KEY} \
-e OPLIST_CLOUD115_UID=${OPLIST_CLOUD115_UID} \
-e OPLIST_CLOUD115_KEY=${OPLIST_CLOUD115_KEY} \
-e OPLIST_GOOGLEUI_UID=${OPLIST_GOOGLEUI_UID} \
-e OPLIST_GOOGLEUI_KEY=${OPLIST_GOOGLEUI_KEY} \
-e OPLIST_YANDEXUI_UID=${OPLIST_YANDEXUI_UID} \
-e OPLIST_YANDEXUI_KEY=${OPLIST_YANDEXUI_KEY} \
-e OPLIST_DROPBOXS_UID=${OPLIST_DROPBOXS_UID} \
-e OPLIST_DROPBOXS_KEY=${OPLIST_DROPBOXS_KEY} \
-e OPLIST_QUARKPAN_UID=${OPLIST_QUARKPAN_UID} \
-e OPLIST_QUARKPAN_KEY=${OPLIST_QUARKPAN_KEY} \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e OPLIST_MAIN_URLS=${container_name}.$domain \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=${container_name}.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}
if [ "$tls" = "true" ]; then
    echo "OpenList API server is running at https://${container_name}.${domain}"
else
    echo "OpenList API server is running at http://${container_name}.${domain}"
fi