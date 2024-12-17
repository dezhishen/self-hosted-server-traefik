#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=moviepilot #pthelper
image=jxxghp/moviepilot:latest 
port=3000
#  **各认证站点对应参数配置如下：**

# |   站点名 |      AUTH_SITE      |                          环境变量                           |
# |:-----------------:|:------------:|:-----------------------------------------------------:|
# |       IYUU        |     iyuu     |                 `IYUU_SIGN`：IYUU登录令牌                  |
# |      憨憨       |    hhclub    |     `HHCLUB_USERNAME`：用户名<br/>`HHCLUB_PASSKEY`：密钥     |
# |     观众     |  audiences   |    `AUDIENCES_UID`：用户ID<br/>`AUDIENCES_PASSKEY`：密钥    |
# |     高清杜比       |   hddolby    |      `HDDOLBY_ID`：用户ID<br/>`HDDOLBY_PASSKEY`：密钥       |
# |       织梦        |     zmpt     |         `ZMPT_UID`：用户ID<br/>`ZMPT_PASSKEY`：密钥         |
# |     自由农场      |   freefarm   |     `FREEFARM_UID`：用户ID<br/>`FREEFARM_PASSKEY`：密钥     |
# |      红豆饭       |    hdfans    |       `HDFANS_UID`：用户ID<br/>`HDFANS_PASSKEY`：密钥       |
# |   冬樱    | wintersakura | `WINTERSAKURA_UID`：用户ID<br/>`WINTERSAKURA_PASSKEY`：密钥 |
# |      红叶PT       |    leaves    |       `LEAVES_UID`：用户ID<br/>`LEAVES_PASSKEY`：密钥       |
# |       1PTBA        |     ptba     |         `PTBA_UID`：用户ID<br/>`PTBA_PASSKEY`：密钥         |
# |      冰淇淋      |   icc2022    |      `ICC2022_UID`：用户ID<br/>`ICC2022_PASSKEY`：密钥      |
# |     杏坛       |   xingtan    |      `XINGTAN_UID`：用户ID<br/>`XINGTAN_PASSKEY`：密钥      |
# |     象站      |   ptvicomo   |     `PTVICOMO_UID`：用户ID<br/>`PTVICOMO_PASSKEY`：密钥     |
# |      AGSVPT       |    agsvpt    |       `AGSVPT_UID`：用户ID<br/>`AGSVPT_PASSKEY`：密钥       |
# |       麒麟       |    hdkyl     |        `HDKYL_UID`：用户ID<br/>`HDKYL_PASSKEY`：密钥        |
# |      青蛙       |    qingwa    |      `QINGWA_UID`：用户ID<br/>`QINGWA_PASSKEY`：密钥        |
# |     蝶粉       |    discfan   |      `DISCFAN_UID`：用户ID<br/>`DISCFAN_PASSKEY`：密钥      |
# |      海胆之家       |    haidan    |      `HAIDAN_ID`：用户ID<br/>`HAIDAN_PASSKEY`：密钥        |
# |      Rousi        |    rousi     |      `ROUSI_UID`：用户ID<br/>`ROUSI_PASSKEY`：密钥         |
# |      Sunny        |    sunny     |      `SUNNY_UID`：用户ID<br/>`SUNNY_PASSKEY`：密钥         |
set_auth_site(){
    echo "当前支持认证站点："
    echo "IYUU: iyuu"
    echo "憨憨: hhclub"
    echo "观众: audiences"
    echo "高清杜比: hddolby"
    echo "织梦: zmpt"
    echo "自由农场: freefarm"
    echo "红豆饭: hdfans"
    echo "冬樱: wintersakura"
    echo "红叶PT: leaves"
    echo "1PTBA: ptba"
    echo "冰淇淋: icc2022"
    echo "杏坛: xingtan"
    echo "象站: ptvicomo"
    echo "AGSVPT: agsvpt"
    echo "麒麟: hdkyl"
    echo "青蛙: qingwa"
    echo "蝶粉: discfan"
    echo "海胆之家: haidan"
    echo "Rousi: rousi"
    echo "Sunny: sunny"
    MOVIEPILOT_AUTH_SITE=$(`dirname $0`/get-args.sh MOVIEPILOT_AUTH_SITE 认证站点)
    if [ -z "$MOVIEPILOT_AUTH_SITE" ]; then
        read -p "请输入认证站点：" MOVIEPILOT_AUTH_SITE
        if [ -z "$MOVIEPILOT_AUTH_SITE" ]; then
            echo "未输入认证站点，退出安装。"
            exit 1
        fi
    fi
    auth_site_str=""
    case $MOVIEPILOT_AUTH_SITE in
        iyuu)
            IYUU_SIGN=$(`dirname $0`/get-args.sh IYUU_SIGN "IYUU登录令牌" )
            if [ -z "$IYUU_SIGN" ]; then
                echo "未输入IYUU登录令牌，退出安装。"
                exit 1
            fi
            auth_site_str="-e IYUU_SIGN=${IYUU_SIGN}"
            ;;
        hhclub)
            HHCLUB_USERNAME=$(`dirname $0`/get-args.sh HHCLUB_USERNAME "憨憨用户名" )
            HHCLUB_PASSKEY=$(`dirname $0`/get-args.sh HHCLUB_PASSKEY "憨憨密钥" )
            if [ -z "$HHCLUB_USERNAME" ] || [ -z "$HHCLUB_PASSKEY" ]; then
                echo "未输入憨憨用户名或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e HHCLUB_USERNAME=${HHCLUB_USERNAME} -e HHCLUB_PASSKEY=${HHCLUB_PASSKEY}"
            ;;
        audiences)
            AUDIENCES_UID=$(`dirname $0`/get-args.sh AUDIENCES_UID "观众用户ID" )
            AUDIENCES_PASSKEY=$(`dirname $0`/get-args.sh AUDIENCES_PASSKEY "观众密钥" )
            if [ -z "$AUDIENCES_UID" ] || [ -z "$AUDIENCES_PASSKEY" ]; then
                echo "未输入观众用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e AUDIENCES_UID=${AUDIENCES_UID} -e AUDIENCES_PASSKEY=${AUDIENCES_PASSKEY}"
            ;;
        hddolby)
            HDDOLBY_ID=$(`dirname $0`/get-args.sh HDDOLBY_ID "高清杜比用户ID" )
            HDDOLBY_PASSKEY=$(`dirname $0`/get-args.sh HDDOLBY_PASSKEY "高清杜比密钥" )
            if [ -z "$HDDOLBY_ID" ] || [ -z "$HDDOLBY_PASSKEY" ]; then
                echo "未输入高清杜比用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e HDDOLBY_ID=${HDDOLBY_ID} -e HDDOLBY_PASSKEY=${HDDOLBY_PASSKEY}"
            ;;
        zmpt)
            ZMPT_UID=$(`dirname $0`/get-args.sh ZMPT_UID "织梦用户ID" )
            ZMPT_PASSKEY=$(`dirname $0`/get-args.sh ZMPT_PASSKEY "织梦密钥" )
            if [ -z "$ZMPT_UID" ] || [ -z "$ZMPT_PASSKEY" ]; then
                echo "未输入织梦用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e ZMPT_UID=${ZMPT_UID} -e ZMPT_PASSKEY=${ZMPT_PASSKEY}"
            ;;
        freefarm)
            FREEFARM_UID=$(`dirname $0`/get-args.sh FREEFARM_UID "自由农场用户ID" )
            FREEFARM_PASSKEY=$(`dirname $0`/get-args.sh FREEFARM_PASSKEY "自由农场密钥" )
            if [ -z "$FREEFARM_UID" ] || [ -z "$FREEFARM_PASSKEY" ]; then
                echo "未输入自由农场用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e FREEFARM_UID=${FREEFARM_UID} -e FREEFARM_PASSKEY=${FREEFARM_PASSKEY}"
            ;;
        hdfans)
            HDFANS_UID=$(`dirname $0`/get-args.sh HDFANS_UID "红豆饭用户ID" )
            HDFANS_PASSKEY=$(`dirname $0`/get-args.sh HDFANS_PASSKEY "红豆饭密钥" )
            if [ -z "$HDFANS_UID" ] || [ -z "$HDFANS_PASSKEY" ]; then
                echo "未输入红豆饭用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e HDFANS_UID=${HDFANS_UID} -e HDFANS_PASSKEY=${HDFANS_PASSKEY}"
            ;;
        wintersakura)
            WINTERSAKURA_UID=$(`dirname $0`/get-args.sh WINTERSAKURA_UID "冬樱用户ID" )
            WINTERSAKURA_PASSKEY=$(`dirname $0`/get-args.sh WINTERSAKURA_PASSKEY "冬樱密钥" )
            if [ -z "$WINTERSAKURA_UID" ] || [ -z "$WINTERSAKURA_PASSKEY" ]; then
                echo "未输入冬樱用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e WINTERSAKURA_UID=${WINTERSAKURA_UID} -e WINTERSAKURA_PASSKEY=${WINTERSAKURA_PASSKEY}"
            ;;
        leaves)
            LEAVES_UID=$(`dirname $0`/get-args.sh LEAVES_UID "红叶PT用户ID" )
            LEAVES_PASSKEY=$(`dirname $0`/get-args.sh LEAVES_PASSKEY "红叶PT密钥" )
            if [ -z "$LEAVES_UID" ] || [ -z "$LEAVES_PASSKEY" ]; then
                echo "未输入红叶PT用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e LEAVES_UID=${LEAVES_UID} -e LEAVES_PASSKEY=${LEAVES_PASSKEY}"
            ;;
        ptba)
            PTBA_UID=$(`dirname $0`/get-args.sh PTBA_UID "1PTBA用户ID" )
            PTBA_PASSKEY=$(`dirname $0`/get-args.sh PTBA_PASSKEY "1PTBA密钥" )
            if [ -z "$PTBA_UID" ] || [ -z "$PTBA_PASSKEY" ]; then
                echo "未输入1PTBA用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e PTBA_UID=${PTBA_UID} -e PTBA_PASSKEY=${PTBA_PASSKEY}"
            ;;
        icc2022)
            ICC2022_UID=$(`dirname $0`/get-args.sh ICC2022_UID "冰淇淋用户ID" )
            ICC2022_PASSKEY=$(`dirname $0`/get-args.sh ICC2022_PASSKEY "冰淇淋密钥" )
            if [ -z "$ICC2022_UID" ] || [ -z "$ICC2022_PASSKEY" ]; then
                echo "未输入冰淇淋用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e ICC2022_UID=${ICC2022_UID} -e ICC2022_PASSKEY=${ICC2022_PASSKEY}"
            ;;
        xingtan)
            XINGTAN_UID=$(`dirname $0`/get-args.sh XINGTAN_UID "杏坛用户ID" )
            XINGTAN_PASSKEY=$(`dirname $0`/get-args.sh XINGTAN_PASSKEY "杏坛密钥" )
            if [ -z "$XINGTAN_UID" ] || [ -z "$XINGTAN_PASSKEY" ]; then
                echo "未输入杏坛用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e XINGTAN_UID=${XINGTAN_UID} -e XINGTAN_PASSKEY=${XINGTAN_PASSKEY}"
            ;;
        ptvicomo)
            PTVICOMO_UID=$(`dirname $0`/get-args.sh PTVICOMO_UID "象站用户ID" )
            PTVICOMO_PASSKEY=$(`dirname $0`/get-args.sh PTVICOMO_PASSKEY "象站密钥" )
            if [ -z "$PTVICOMO_UID" ] || [ -z "$PTVICOMO_PASSKEY" ]; then
                echo "未输入象站用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e PTVICOMO_UID=${PTVICOMO_UID} -e PTVICOMO_PASSKEY=${PTVICOMO_PASSKEY}"
            ;;
        agsvpt)
            AGSVPT_UID=$(`dirname $0`/get-args.sh AGSVPT_UID "麒麟用户ID" )
            AGSVPT_PASSKEY=$(`dirname $0`/get-args.sh AGSVPT_PASSKEY "麒麟密钥" )
            if [ -z "$AGSVPT_UID" ] || [ -z "$AGSVPT_PASSKEY" ]; then
                echo "未输入麒麟用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e AGSVPT_UID=${AGSVPT_UID} -e AGSVPT_PASSKEY=${AGSVPT_PASSKEY}"
            ;;
        hdkyl)
            HDKYL_UID=$(`dirname $0`/get-args.sh HDKYL_UID "麒麟用户ID" )
            HDKYL_PASSKEY=$(`dirname $0`/get-args.sh HDKYL_PASSKEY "麒麟密钥" )
            if [ -z "$HDKYL_UID" ] || [ -z "$HDKYL_PASSKEY" ]; then
                echo "未输入麒麟用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e HDKYL_UID=${HDKYL_UID} -e HDKYL_PASSKEY=${HDKYL_PASSKEY}"
            ;;
        qingwa)
            QINGWA_UID=$(`dirname $0`/get-args.sh QINGWA_UID "青蛙用户ID" )
            QINGWA_PASSKEY=$(`dirname $0`/get-args.sh QINGWA_PASSKEY "青蛙密钥" )
            if [ -z "$QINGWA_UID" ] || [ -z "$QINGWA_PASSKEY" ]; then
                echo "未输入青蛙用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e QINGWA_UID=${QINGWA_UID} -e QINGWA_PASSKEY=${QINGWA_PASSKEY}"
            ;;
        discfan)
            DISCFAN_UID=$(`dirname $0`/get-args.sh DISCFAN_UID "蝶粉用户ID" )
            DISCFAN_PASSKEY=$(`dirname $0`/get-args.sh DISCFAN_PASSKEY "蝶粉密钥" )
            if [ -z "$DISCFAN_UID" ] || [ -z "$DISCFAN_PASSKEY" ]; then
                echo "未输入蝶粉用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e DISCFAN_UID=${DISCFAN_UID} -e DISCFAN_PASSKEY=${DISCFAN_PASSKEY}"
            ;;
        haidan)
            HAIDAN_ID=$(`dirname $0`/get-args.sh HAIDAN_ID "海胆之家用户ID" )
            HAIDAN_PASSKEY=$(`dirname $0`/get-args.sh HAIDAN_PASSKEY "海胆之家密钥" )
            if [ -z "$HAIDAN_ID" ] || [ -z "$HAIDAN_PASSKEY" ]; then
                echo "未输入海胆之家用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e HAIDAN_ID=${HAIDAN_ID} -e HAIDAN_PASSKEY=${HAIDAN_PASSKEY}"
            ;;  
        rousi)
            ROUSI_UID=$(`dirname $0`/get-args.sh ROUSI_UID "Rousi用户ID" )
            ROUSI_PASSKEY=$(`dirname $0`/get-args.sh ROUSI_PASSKEY "Rousi密钥" )
            if [ -z "$ROUSI_UID" ] || [ -z "$ROUSI_PASSKEY" ]; then
                echo "未输入Rousi用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e ROUSI_UID=${ROUSI_UID} -e ROUSI_PASSKEY=${ROUSI_PASSKEY}"
            ;;
        sunny)
            SUNNY_UID=$(`dirname $0`/get-args.sh SUNNY_UID "Sunny用户ID" )
            SUNNY_PASSKEY=$(`dirname $0`/get-args.sh SUNNY_PASSKEY "Sunny密钥" )
            if [ -z "$SUNNY_UID" ] || [ -z "$SUNNY_PASSKEY" ]; then
                echo "未输入Sunny用户ID或密钥，退出安装。"
                exit 1
            fi
            auth_site_str="-e SUNNY_UID=${SUNNY_UID} -e SUNNY_PASSKEY=${SUNNY_PASSKEY}"
            ;;
        *)
            echo "未输入认证站点，退出安装。"
            exit 1
            ;;
    esac
}
set_auth_site
docker pull ${image}
`dirname $0`/stop-container.sh ${container_name}
docker run --name=${container_name} \
-m 512M \
-d --restart=always \
-e PUID=`id -u` \
-e PGID=`id -g` \
-e UMASK=022 \
-e DOH=False \
-e TZ="Asia/Shanghai" \
-e LANG="zh_CN.UTF-8" \
-e AUTH_SITE=${MOVIEPILOT_AUTH_SITE} \
${auth_site_str} \
--network=$docker_network_name --network-alias=${container_name} \
-v $base_data_dir/${container_name}/config:/config \
-v $base_data_dir/public/:/data \
-v $base_data_dir/${container_name}/core:/moviepilot/.cache/ms-playwright \
-v /var/run/docker.sock:/var/run/docker.sock:ro \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}