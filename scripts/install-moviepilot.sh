#!/bin/bash
domain=$1
base_data_dir=$2
docker_network_name=$3
tls=$4
container_name=moviepilot #pthelper
image=jxxghp/moviepilot-v2:latest
port=3000
#  **各认证站点对应参数配置如下：**

# |  站点名   |  AUTH_SITE   |                                环境变量                                 |
# |:------:|:------------:|:-------------------------------------------------------------------:|
# |  IYUU  |     iyuu     |                        `IYUU_SIGN`：IYUU登录令牌                         |
# |   憨憨   |    hhclub    |            `HHCLUB_USERNAME`：用户名<br/>`HHCLUB_PASSKEY`：密钥            |
# |   观众   |  audiences   |           `AUDIENCES_UID`：用户ID<br/>`AUDIENCES_PASSKEY`：密钥           |
# |  高清杜比  |   hddolby    |             `HDDOLBY_ID`：用户ID<br/>`HDDOLBY_PASSKEY`：密钥              |
# |   织梦   |     zmpt     |                `ZMPT_UID`：用户ID<br/>`ZMPT_PASSKEY`：密钥                |
# |  自由农场  |   freefarm   |            `FREEFARM_UID`：用户ID<br/>`FREEFARM_PASSKEY`：密钥            |
# |  红豆饭   |    hdfans    |              `HDFANS_UID`：用户ID<br/>`HDFANS_PASSKEY`：密钥              |
# |   冬樱   | wintersakura |        `WINTERSAKURA_UID`：用户ID<br/>`WINTERSAKURA_PASSKEY`：密钥        |
# |  红叶PT  |    leaves    |              `LEAVES_UID`：用户ID<br/>`LEAVES_PASSKEY`：密钥              |
# | 1PTBA  |     ptba     |                `PTBA_UID`：用户ID<br/>`PTBA_PASSKEY`：密钥                |
# |  冰淇淋   |   icc2022    |             `ICC2022_UID`：用户ID<br/>`ICC2022_PASSKEY`：密钥             |
# |   杏坛   |   xingtan    |             `XINGTAN_UID`：用户ID<br/>`XINGTAN_PASSKEY`：密钥             |
# |   象站   |   ptvicomo   |            `PTVICOMO_UID`：用户ID<br/>`PTVICOMO_PASSKEY`：密钥            |
# | AGSVPT |    agsvpt    |              `AGSVPT_UID`：用户ID<br/>`AGSVPT_PASSKEY`：密钥              |
# |   麒麟   |    hdkyl     |               `HDKYL_UID`：用户ID<br/>`HDKYL_PASSKEY`：密钥               |
# |   青蛙   |    qingwa    |              `QINGWA_UID`：用户ID<br/>`QINGWA_PASSKEY`：密钥              |
# |   蝶粉   |   discfan    |             `DISCFAN_UID`：用户ID<br/>`DISCFAN_PASSKEY`：密钥             |
# |  海胆之家  |    haidan    |              `HAIDAN_ID`：用户ID<br/>`HAIDAN_PASSKEY`：密钥               |
# | Rousi  |    rousi     |               `ROUSI_UID`：用户ID<br/>`ROUSI_PASSKEY`：密钥               |
# | Sunny  |    sunny     |               `SUNNY_UID`：用户ID<br/>`SUNNY_PASSKEY`：密钥               |
# |   咖啡   |    ptcafe    |              `PTCAFE_UID`：用户ID<br/>`PTCAFE_PASSKEY`：密钥              |
# | PTZone |    ptzone    |              `PTZONE_UID`：用户ID<br/>`PTZONE_PASSKEY`：密钥              |
# |   库非   |    kufei     |               `KUFEI_UID`：用户ID<br/>`KUFEI_PASSKEY`：密钥               |
# | YemaPT |    yemapt    |     `YEMAPT_UID`：用户ID<br/>`YEMAPT_AUTH`：密钥<br/>注意：需v2.2.0或以上版本      |
#  |   回声   |     hspt     |       `HSPT_UID`：用户ID<br/>`HSPT_AUTH`：密钥        |
# |  星陨阁   |  xingyunge   | `XINGYUNGE_UID`：用户ID<br/>`XINGYUNGE_PASSKEY`：密钥 |
# |   财神   |     cspt     |      `CSPT_UID`：用户ID<br/>`CSPT_PASSKEY`：密钥      |
# |   唐门   |     tmpt     |      `TMPT_UID`：用户ID<br/>`TMPT_PASSKEY`：密钥      |
# |   雨    |   raingfh    |   `RAINGFH_UID`：用户ID<br/>`RAINGFH_PASSKEY`：密钥   |
# |   GTK    |   gtkpw    |   `GTKPW_UID`：用户ID<br/>`GTKPW_PASSKEY`：密钥   |
# |   PTLGS    |   ptlgs    |   `PTLGS_UID`：用户ID<br/>`PTLGS_PASSKEY`：密钥   |
# |   HDBAO    |   hdbao    |   `HDBAO_UID`：用户ID<br/>`HDBAO_PASSKEY`：密钥   |
# |   下水道    |   sewerpt    |   `SEWERPT_UID`：用户ID<br/>`SEWERPT_PASSKEY`：密钥   |


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
    echo "咖啡: ptcafe"
    echo "PTZone: ptzone"
    echo "库非: kufei"
    echo "YemaPT: yemapt"
    echo "回声: hspt"
    echo "星陨阁: xingyunge"
    echo "财神: cspt"
    echo "唐门: tmpt"
    echo "雨: raingfh"
    echo "GTK: gtkpw"
    echo "PTLGS: ptlgs"
    echo "HDBAO: hdbao"
    echo "下水道: sewerpt"
    MOVIEPILOT_AUTH_SITE=$(`dirname $0`/get-args.sh MOVIEPILOT_AUTH_SITE 认证站点)
    if [ -z "$MOVIEPILOT_AUTH_SITE" ]; then
        read -p "请输入认证站点：" MOVIEPILOT_AUTH_SITE
        if [ -z "$MOVIEPILOT_AUTH_SITE" ]; then
            echo "未输入认证站点，退出安装。"
            exit 1
        fi
        `dirname $0`/set-args.sh MOVIEPILOT_AUTH_SITE "$MOVIEPILOT_AUTH_SITE"
    fi
    auth_site_str=""
    case $MOVIEPILOT_AUTH_SITE in
        iyuu)
            IYUU_SIGN=$(`dirname $0`/get-args.sh IYUU_SIGN "IYUU登录令牌" )
            if [ -z "$IYUU_SIGN" ]; then
                echo "未输入IYUU登录令牌，退出安装。"
                exit 1
            fi
            `dirname $0`/set-args.sh IYUU_SIGN "$IYUU_SIGN"
            auth_site_str="-e IYUU_SIGN=${IYUU_SIGN}"
            ;;
        hhclub)
            HHCLUB_USERNAME=$(`dirname $0`/get-args.sh HHCLUB_USERNAME "憨憨用户名" )
            if [ -z "$HHCLUB_USERNAME" ]; then
                read -p "请输入憨憨用户名:" HHCLUB_USERNAME
                if [ -z "$HHCLUB_USERNAME" ]; then
                    echo "未输入憨憨用户名，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HHCLUB_USERNAME "$HHCLUB_USERNAME"
            fi
            HHCLUB_PASSKEY=$(`dirname $0`/get-args.sh HHCLUB_PASSKEY "憨憨密钥" )
            if [ -z "$HHCLUB_PASSKEY" ]; then
                read -p "请输入憨憨密钥:" HHCLUB_PASSKEY
                if [ -z "$HHCLUB_PASSKEY" ]; then
                    echo "未输入憨憨密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HHCLUB_PASSKEY "$HHCLUB_PASSKEY"
            fi
            auth_site_str="-e HHCLUB_USERNAME=${HHCLUB_USERNAME} -e HHCLUB_PASSKEY=${HHCLUB_PASSKEY}"
            ;;
        audiences)
            AUDIENCES_UID=$(`dirname $0`/get-args.sh AUDIENCES_UID "观众用户ID" )
            if [ -z "$AUDIENCES_UID" ]; then
                read -p "请输入观众用户ID:" AUDIENCES_UID
                if [ -z "$AUDIENCES_UID" ]; then
                    echo "未输入观众用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh AUDIENCES_UID "$AUDIENCES_UID"
            fi
            AUDIENCES_PASSKEY=$(`dirname $0`/get-args.sh AUDIENCES_PASSKEY "观众密钥" )
            if [ -z "$AUDIENCES_PASSKEY" ]; then
                read -p "请输入观众密钥:" AUDIENCES_PASSKEY
                if [ -z "$AUDIENCES_PASSKEY" ]; then
                    echo "未输入观众密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh AUDIENCES_PASSKEY "$AUDIENCES_PASSKEY"
            fi
            auth_site_str="-e AUDIENCES_UID=${AUDIENCES_UID} -e AUDIENCES_PASSKEY=${AUDIENCES_PASSKEY}"
            ;;
        hddolby)
            HDDOLBY_ID=$(`dirname $0`/get-args.sh HDDOLBY_ID "高清杜比用户ID" )
            if [ -z "$HDDOLBY_ID" ]; then
                read -p "请输入高清杜比用户ID:" HDDOLBY_ID
                if [ -z "$HDDOLBY_ID" ]; then
                    echo "未输入高清杜比用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDDOLBY_ID "$HDDOLBY_ID"
            fi
            HDDOLBY_PASSKEY=$(`dirname $0`/get-args.sh HDDOLBY_PASSKEY "高清杜比密钥" )
            if [ -z "$HDDOLBY_PASSKEY" ]; then
                read -p "请输入高清杜比密钥:" HDDOLBY_PASSKEY
                if [ -z "$HDDOLBY_PASSKEY" ]; then
                    echo "未输入高清杜比密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDDOLBY_PASSKEY "$HDDOLBY_PASSKEY"
            fi
            auth_site_str="-e HDDOLBY_ID=${HDDOLBY_ID} -e HDDOLBY_PASSKEY=${HDDOLBY_PASSKEY}"
            ;;
        zmpt)
            ZMPT_UID=$(`dirname $0`/get-args.sh ZMPT_UID "织梦用户ID" )
            if [ -z "$ZMPT_UID" ]; then
                read -p "请输入织梦用户ID:" ZMPT_UID
                if [ -z "$ZMPT_UID" ]; then
                    echo "未输入织梦用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh ZMPT_UID "$ZMPT_UID"
            fi
            ZMPT_PASSKEY=$(`dirname $0`/get-args.sh ZMPT_PASSKEY "织梦密钥" )
            if [ -z "$ZMPT_PASSKEY" ]; then
                read -p "请输入织梦密钥:" ZMPT_PASSKEY
                if [ -z "$ZMPT_PASSKEY" ]; then
                    echo "未输入织梦密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh ZMPT_PASSKEY "$ZMPT_PASSKEY"
            fi
            auth_site_str="-e ZMPT_UID=${ZMPT_UID} -e ZMPT_PASSKEY=${ZMPT_PASSKEY}"
            ;;
        freefarm)
            FREEFARM_UID=$(`dirname $0`/get-args.sh FREEFARM_UID "自由农场用户ID" )
            if [ -z "$FREEFARM_UID" ]; then
                read -p "请输入自由农场用户ID:" FREEFARM_UID
                if [ -z "$FREEFARM_UID" ]; then
                    echo "未输入自由农场用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh FREEFARM_UID "$FREEFARM_UID"
            fi
            FREEFARM_PASSKEY=$(`dirname $0`/get-args.sh FREEFARM_PASSKEY "自由农场密钥" )
            if [ -z "$FREEFARM_PASSKEY" ]; then
                read -p "请输入自由农场密钥:" FREEFARM_PASSKEY
                if [ -z "$FREEFARM_PASSKEY" ]; then
                    echo "未输入自由农场密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh FREEFARM_PASSKEY "$FREEFARM_PASSKEY"
            fi
            auth_site_str="-e FREEFARM_UID=${FREEFARM_UID} -e FREEFARM_PASSKEY=${FREEFARM_PASSKEY}"
            ;;
        hdfans)
            HDFANS_UID=$(`dirname $0`/get-args.sh HDFANS_UID "红豆饭用户ID" )
            if [ -z "$HDFANS_UID" ]; then
                read -p "请输入红豆饭用户ID:" HDFANS_UID
                if [ -z "$HDFANS_UID" ]; then
                    echo "未输入红豆饭用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDFANS_UID "$HDFANS_UID"
            fi
            HDFANS_PASSKEY=$(`dirname $0`/get-args.sh HDFANS_PASSKEY "红豆饭密钥" )
            if [ -z "$HDFANS_PASSKEY" ]; then
                read -p "请输入红豆饭密钥:" HDFANS_PASSKEY
                if [ -z "$HDFANS_PASSKEY" ]; then
                    echo "未输入红豆饭密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDFANS_PASSKEY "$HDFANS_PASSKEY"
            fi
            auth_site_str="-e HDFANS_UID=${HDFANS_UID} -e HDFANS_PASSKEY=${HDFANS_PASSKEY}"
            ;;
        wintersakura)
            WINTERSAKURA_UID=$(`dirname $0`/get-args.sh WINTERSAKURA_UID "冬樱用户ID" )
            if [ -z "$WINTERSAKURA_UID" ]; then
                read -p "请输入冬樱用户ID:" WINTERSAKURA_UID
                if [ -z "$WINTERSAKURA_UID" ]; then
                    echo "未输入冬樱用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh WINTERSAKURA_UID "$WINTERSAKURA_UID"
            fi
            WINTERSAKURA_PASSKEY=$(`dirname $0`/get-args.sh WINTERSAKURA_PASSKEY "冬樱密钥" )
            if [ -z "$WINTERSAKURA_PASSKEY" ]; then
                read -p "请输入冬樱密钥:" WINTERSAKURA_PASSKEY
                if [ -z "$WINTERSAKURA_PASSKEY" ]; then
                    echo "未输入冬樱密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh WINTERSAKURA_PASSKEY "$WINTERSAKURA_PASSKEY"
            fi
            auth_site_str="-e WINTERSAKURA_UID=${WINTERSAKURA_UID} -e WINTERSAKURA_PASSKEY=${WINTERSAKURA_PASSKEY}"
            ;;
        leaves)
            LEAVES_UID=$(`dirname $0`/get-args.sh LEAVES_UID "红叶PT用户ID" )
            if [ -z "$LEAVES_UID" ]; then
                read -p "请输入红叶PT用户ID:" LEAVES_UID
                if [ -z "$LEAVES_UID" ]; then
                    echo "未输入红叶PT用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh LEAVES_UID "$LEAVES_UID"
            fi
            LEAVES_PASSKEY=$(`dirname $0`/get-args.sh LEAVES_PASSKEY "红叶PT密钥" )
            if [ -z "$LEAVES_PASSKEY" ]; then
                read -p "请输入红叶PT密钥:" LEAVES_PASSKEY
                if [ -z "$LEAVES_PASSKEY" ]; then
                    echo "未输入红叶PT密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh LEAVES_PASSKEY "$LEAVES_PASSKEY"
            fi
            auth_site_str="-e LEAVES_UID=${LEAVES_UID} -e LEAVES_PASSKEY=${LEAVES_PASSKEY}"
            ;;
        ptba)
            PTBA_UID=$(`dirname $0`/get-args.sh PTBA_UID "1PTBA用户ID" )
            if [ -z "$PTBA_UID" ]; then
                read -p "请输入1PTBA用户ID:" PTBA_UID
                if [ -z "$PTBA_UID" ]; then
                    echo "未输入1PTBA用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTBA_UID "$PTBA_UID"
            fi
            PTBA_PASSKEY=$(`dirname $0`/get-args.sh PTBA_PASSKEY "1PTBA密钥" )
            if [ -z "$PTBA_PASSKEY" ]; then
                read -p "请输入1PTBA密钥:" PTBA_PASSKEY
                if [ -z "$PTBA_PASSKEY" ]; then
                    echo "未输入1PTBA密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTBA_PASSKEY "$PTBA_PASSKEY"
            fi
            auth_site_str="-e PTBA_UID=${PTBA_UID} -e PTBA_PASSKEY=${PTBA_PASSKEY}"
            ;;
        icc2022)
            ICC2022_UID=$(`dirname $0`/get-args.sh ICC2022_UID "冰淇淋用户ID" )
            if [ -z "$ICC2022_UID" ]; then
                read -p "请输入冰淇淋用户ID:" ICC2022_UID
                if [ -z "$ICC2022_UID" ]; then
                    echo "未输入冰淇淋用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh ICC2022_UID "$ICC2022_UID"
            fi
            ICC2022_PASSKEY=$(`dirname $0`/get-args.sh ICC2022_PASSKEY "冰淇淋密钥" )
            if [ -z "$ICC2022_PASSKEY" ]; then
                read -p "请输入冰淇淋密钥:" ICC2022_PASSKEY
                if [ -z "$ICC2022_PASSKEY" ]; then
                    echo "未输入冰淇淋密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh ICC2022_PASSKEY "$ICC2022_PASSKEY"
            fi
            auth_site_str="-e ICC2022_UID=${ICC2022_UID} -e ICC2022_PASSKEY=${ICC2022_PASSKEY}"
            ;;
        xingtan)
            XINGTAN_UID=$(`dirname $0`/get-args.sh XINGTAN_UID "杏坛用户ID" )
            if [ -z "$XINGTAN_UID" ]; then
                read -p "请输入杏坛用户ID:" XINGTAN_UID
                if [ -z "$XINGTAN_UID" ]; then
                    echo "未输入杏坛用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh XINGTAN_UID "$XINGTAN_UID"
            fi
            XINGTAN_PASSKEY=$(`dirname $0`/get-args.sh XINGTAN_PASSKEY "杏坛密钥" )
            if [ -z "$XINGTAN_PASSKEY" ]; then
                read -p "请输入杏坛密钥:" XINGTAN_PASSKEY
                if [ -z "$XINGTAN_PASSKEY" ]; then
                    echo "未输入杏坛密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh XINGTAN_PASSKEY "$XINGTAN_PASSKEY"
            fi
            auth_site_str="-e XINGTAN_UID=${XINGTAN_UID} -e XINGTAN_PASSKEY=${XINGTAN_PASSKEY}"
            ;;
        ptvicomo)
            PTVICOMO_UID=$(`dirname $0`/get-args.sh PTVICOMO_UID "象站用户ID" )
            if [ -z "$PTVICOMO_UID" ]; then
                read -p "请输入象站用户ID:" PTVICOMO_UID
                if [ -z "$PTVICOMO_UID" ]; then
                    echo "未输入象站用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTVICOMO_UID "$PTVICOMO_UID"
            fi
            PTVICOMO_PASSKEY=$(`dirname $0`/get-args.sh PTVICOMO_PASSKEY "象站密钥" )
            if [ -z "$PTVICOMO_PASSKEY" ]; then
                read -p "请输入象站密钥:" PTVICOMO_PASSKEY
                if [ -z "$PTVICOMO_PASSKEY" ]; then
                    echo "未输入象站密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTVICOMO_PASSKEY "$PTVICOMO_PASSKEY"
            fi
            auth_site_str="-e PTVICOMO_UID=${PTVICOMO_UID} -e PTVICOMO_PASSKEY=${PTVICOMO_PASSKEY}"
            ;;
        agsvpt)
            AGSVPT_UID=$(`dirname $0`/get-args.sh AGSVPT_UID "AGSVPTID" )
            if [ -z "$AGSVPT_UID" ]; then
                read -p "请输入AGSVPTID:" AGSVPT_UID
                if [ -z "$AGSVPT_UID" ]; then
                    echo "未输入AGSVPTID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh AGSVPT_UID "$AGSVPT_UID"
            fi
            AGSVPT_PASSKEY=$(`dirname $0`/get-args.sh AGSVPT_PASSKEY "AGSVPT密钥" )
            if [ -z "$AGSVPT_PASSKEY" ]; then
                read -p "请输入AGSVPT密钥:" AGSVPT_PASSKEY
                if [ -z "$AGSVPT_PASSKEY" ]; then
                    echo "未输入AGSVPT密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh AGSVPT_PASSKEY "$AGSVPT_PASSKEY"
            fi
            auth_site_str="-e AGSVPT_UID=${AGSVPT_UID} -e AGSVPT_PASSKEY=${AGSVPT_PASSKEY}"
            ;;
        hdkyl)
            HDKYL_UID=$(`dirname $0`/get-args.sh HDKYL_UID "麒麟用户ID" )
            if [ -z "$HDKYL_UID" ]; then
                read -p "请输入麒麟用户ID:" HDKYL_UID
                if [ -z "$HDKYL_UID" ]; then
                    echo "未输入麒麟用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDKYL_UID "$HDKYL_UID"
            fi
            HDKYL_PASSKEY=$(`dirname $0`/get-args.sh HDKYL_PASSKEY "麒麟密钥" )
            if [ -z "$HDKYL_PASSKEY" ]; then
                read -p "请输入麒麟密钥:" HDKYL_PASSKEY
                if [ -z "$HDKYL_PASSKEY" ]; then
                    echo "未输入麒麟密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDKYL_PASSKEY "$HDKYL_PASSKEY"
            fi
            auth_site_str="-e HDKYL_UID=${HDKYL_UID} -e HDKYL_PASSKEY=${HDKYL_PASSKEY}"
            ;;
        qingwa)
            QINGWA_UID=$(`dirname $0`/get-args.sh QINGWA_UID "青蛙用户ID" )
            if [ -z "$QINGWA_UID" ]; then
                read -p "请输入青蛙用户ID:" QINGWA_UID
                if [ -z "$QINGWA_UID" ]; then
                    echo "未输入青蛙用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh QINGWA_UID "$QINGWA_UID"
            fi
            QINGWA_PASSKEY=$(`dirname $0`/get-args.sh QINGWA_PASSKEY "青蛙密钥" )
            if [ -z "$QINGWA_PASSKEY" ]; then
                read -p "请输入青蛙密钥:" QINGWA_PASSKEY
                if [ -z "$QINGWA_PASSKEY" ]; then
                    echo "未输入青蛙密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh QINGWA_PASSKEY "$QINGWA_PASSKEY"
            fi
            auth_site_str="-e QINGWA_UID=${QINGWA_UID} -e QINGWA_PASSKEY=${QINGWA_PASSKEY}"
            ;;
        discfan)
            DISCFAN_UID=$(`dirname $0`/get-args.sh DISCFAN_UID "蝶粉用户ID" )
            if [ -z "$DISCFAN_UID" ]; then
                read -p "请输入蝶粉用户ID:" DISCFAN_UID
                if [ -z "$DISCFAN_UID" ]; then
                    echo "未输入蝶粉用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh DISCFAN_UID "$DISCFAN_UID"
            fi
            DISCFAN_PASSKEY=$(`dirname $0`/get-args.sh DISCFAN_PASSKEY "蝶粉密钥" )
            if [ -z "$DISCFAN_PASSKEY" ]; then
                read -p "请输入蝶粉密钥:" DISCFAN_PASSKEY
                if [ -z "$DISCFAN_PASSKEY" ]; then
                    echo "未输入蝶粉密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh DISCFAN_PASSKEY "$DISCFAN_PASSKEY"
            fi
            auth_site_str="-e DISCFAN_UID=${DISCFAN_UID} -e DISCFAN_PASSKEY=${DISCFAN_PASSKEY}"
            ;;
        haidan)
            HAIDAN_ID=$(`dirname $0`/get-args.sh HAIDAN_ID "海胆之家用户ID" )
            if [ -z "$HAIDAN_ID" ]; then
                read -p "请输入海胆之家用户ID:" HAIDAN_ID
                if [ -z "$HAIDAN_ID" ]; then
                    echo "未输入海胆之家用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HAIDAN_ID "$HAIDAN_ID"
            fi
            HAIDAN_PASSKEY=$(`dirname $0`/get-args.sh HAIDAN_PASSKEY "海胆之家密钥" )
            if [ -z "$HAIDAN_PASSKEY" ]; then
                read -p "请输入海胆之家密钥:" HAIDAN_PASSKEY
                if [ -z "$HAIDAN_PASSKEY" ]; then
                    echo "未输入海胆之家密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HAIDAN_PASSKEY "$HAIDAN_PASSKEY"
            fi
            auth_site_str="-e HAIDAN_ID=${HAIDAN_ID} -e HAIDAN_PASSKEY=${HAIDAN_PASSKEY}"
            ;;  
        rousi)
            ROUSI_UID=$(`dirname $0`/get-args.sh ROUSI_UID "Rousi用户ID" )
            if [ -z "$ROUSI_UID" ]; then
                read -p "请输入Rousi用户ID:" ROUSI_UID
                if [ -z "$ROUSI_UID" ]; then
                    echo "未输入Rousi用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh ROUSI_UID "$ROUSI_UID"
            fi
            ROUSI_PASSKEY=$(`dirname $0`/get-args.sh ROUSI_PASSKEY "Rousi密钥" )
            if [ -z "$ROUSI_PASSKEY" ]; then
                read -p "请输入Rousi密钥:" ROUSI_PASSKEY
                if [ -z "$ROUSI_PASSKEY" ]; then
                    echo "未输入Rousi密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh ROUSI_PASSKEY "$ROUSI_PASSKEY"
            fi
            auth_site_str="-e ROUSI_UID=${ROUSI_UID} -e ROUSI_PASSKEY=${ROUSI_PASSKEY}"
            ;;
        sunny)
            SUNNY_UID=$(`dirname $0`/get-args.sh SUNNY_UID "Sunny用户ID" )
            if [ -z "$SUNNY_UID" ]; then
                read -p "请输入Sunny用户ID:" SUNNY_UID
                if [ -z "$SUNNY_UID" ]; then
                    echo "未输入Sunny用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh SUNNY_UID "$SUNNY_UID"
            fi
            SUNNY_PASSKEY=$(`dirname $0`/get-args.sh SUNNY_PASSKEY "Sunny密钥" )
            if [ -z "$SUNNY_PASSKEY" ]; then
                read -p "请输入Sunny密钥:" SUNNY_PASSKEY
                if [ -z "$SUNNY_PASSKEY" ]; then
                    echo "未输入Sunny密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh SUNNY_PASSKEY "$SUNNY_PASSKEY"
            fi
            auth_site_str="-e SUNNY_UID=${SUNNY_UID} -e SUNNY_PASSKEY=${SUNNY_PASSKEY}"
            ;;
        ptcafe)
            PTCAFE_UID=$(`dirname $0`/get-args.sh PTCAFE_UID "咖啡用户ID" )
            if [ -z "$PTCAFE_UID" ]; then
                read -p "请输入咖啡用户ID:" PTCAFE_UID
                if [ -z "$PTCAFE_UID" ]; then
                    echo "未输入咖啡用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTCAFE_UID "$PTCAFE_UID"
            fi
            PTCAFE_PASSKEY=$(`dirname $0`/get-args.sh PTCAFE_PASSKEY "咖啡密钥" )
            if [ -z "$PTCAFE_PASSKEY" ]; then
                read -p "请输入咖啡密钥:" PTCAFE_PASSKEY
                if [ -z "$PTCAFE_PASSKEY" ]; then
                    echo "未输入咖啡密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTCAFE_PASSKEY "$PTCAFE_PASSKEY"
            fi
            auth_site_str="-e PTCAFE_UID=${PTCAFE_UID} -e PTCAFE_PASSKEY=${PTCAFE_PASSKEY}"
            ;;
        ptzone)
            PTZONE_UID=$(`dirname $0`/get-args.sh PTZONE_UID "PTZone用户ID" )
            if [ -z "$PTZONE_UID" ]; then
                read -p "请输入PTZone用户ID:" PTZONE_UID
                if [ -z "$PTZONE_UID" ]; then
                    echo "未输入PTZone用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTZONE_UID "$PTZONE_UID"
            fi
            PTZONE_PASSKEY=$(`dirname $0`/get-args.sh PTZONE_PASSKEY "PTZone密钥" )
            if [ -z "$PTZONE_PASSKEY" ]; then
                read -p "请输入PTZone密钥:" PTZONE_PASSKEY
                if [ -z "$PTZONE_PASSKEY" ]; then
                    echo "未输入PTZone密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTZONE_PASSKEY "$PTZONE_PASSKEY"
            fi
            auth_site_str="-e PTZONE_UID=${PTZONE_UID} -e PTZONE_PASSKEY=${PTZONE_PASSKEY}"
            ;;
        kufei)
            KUFEI_UID=$(`dirname $0`/get-args.sh KUFEI_UID "库非用户ID" )
            if [ -z "$KUFEI_UID" ]; then
                read -p "请输入库非用户ID:" KUFEI_UID
                if [ -z "$KUFEI_UID" ]; then
                    echo "未输入库非用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh KUFEI_UID "$KUFEI_UID"
            fi
            KUFEI_PASSKEY=$(`dirname $0`/get-args.sh KUFEI_PASSKEY "库非密钥" )
            if [ -z "$KUFEI_PASSKEY" ]; then
                read -p "请输入库非密钥:" KUFEI_PASSKEY
                if [ -z "$KUFEI_PASSKEY" ]; then
                    echo "未输入库非密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh KUFEI_PASSKEY "$KUFEI_PASSKEY"
            fi
            auth_site_str="-e KUFEI_UID=${KUFEI_UID} -e KUFEI_PASSKEY=${KUFEI_PASSKEY}"
            ;;
        yemapt)
            YEMAPT_UID=$(`dirname $0`/get-args.sh YEMAPT_UID "YemaPT用户ID" )
            if [ -z "$YEMAPT_UID" ]; then
                read -p "请输入YemaPT用户ID:" YEMAPT_UID
                if [ -z "$YEMAPT_UID" ]; then
                    echo "未输入YemaPT用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh YEMAPT_UID "$YEMAPT_UID"
            fi
            YEMAPT_PASSKEY=$(`dirname $0`/get-args.sh YEMAPT_PASSKEY "YemaPT密钥" )
            if [ -z "$YEMAPT_PASSKEY" ]; then
                read -p "请输入YemaPT密钥:" YEMAPT_PASSKEY
                if [ -z "$YEMAPT_PASSKEY" ]; then
                    echo "未输入YemaPT密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh YEMAPT_PASSKEY "$YEMAPT_PASSKEY"
            fi
            auth_site_str="-e YEMAPT_UID=${YEMAPT_UID} -e YEMAPT_PASSKEY=${YEMAPT_PASSKEY}"
            ;;
        hspt)
            HSPT_UID=$(`dirname $0`/get-args.sh HSPT_UID "HSPT用户ID" )
            if [ -z "$HSPT_UID" ]; then
                read -p "请输入HSPT用户ID:" HSPT_UID
                if [ -z "$HSPT_UID" ]; then
                    echo "未输入HSPT用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HSPT_UID "$HSPT_UID"
            fi
            HSPT_PASSKEY=$(`dirname $0`/get-args.sh HSPT_PASSKEY "HSPT密钥" )
            if [ -z "$HSPT_PASSKEY" ]; then
                read -p "请输入HSPT密钥:" HSPT_PASSKEY
                if [ -z "$HSPT_PASSKEY" ]; then
                    echo "未输入HSPT密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HSPT_PASSKEY "$HSPT_PASSKEY"
            fi
            auth_site_str="-e HSPT_UID=${HSPT_UID} -e HSPT_PASSKEY=${HSPT_PASSKEY}"
            ;;
        xingyunge)
            XINGYUNGE_UID=$(`dirname $0`/get-args.sh XINGYUNGE_UID "星云阁用户ID" )
            if [ -z "$XINGYUNGE_UID" ]; then
                read -p "请输入星云阁用户ID:" XINGYUNGE_UID
                if [ -z "$XINGYUNGE_UID" ]; then
                    echo "未输入星云阁用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh XINGYUNGE_UID "$XINGYUNGE_UID"
            fi
            XINGYUNGE_PASSKEY=$(`dirname $0`/get-args.sh XINGYUNGE_PASSKEY "星云阁密钥" )
            if [ -z "$XINGYUNGE_PASSKEY" ]; then
                read -p "请输入星云阁密钥:" XINGYUNGE_PASSKEY
                if [ -z "$XINGYUNGE_PASSKEY" ]; then
                    echo "未输入星云阁密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh XINGYUNGE_PASSKEY "$XINGYUNGE_PASSKEY"
            fi
            auth_site_str="-e XINGYUNGE_UID=${XINGYUNGE_UID} -e XINGYUNGE_PASSKEY=${XINGYUNGE_PASSKEY}"
            ;;
        cspt)
            CSPT_UID=$(`dirname $0`/get-args.sh CSPT_UID "财神用户ID" )
            if [ -z "$CSPT_UID" ]; then
                read -p "请输入财神用户ID:" CSPT_UID
                if [ -z "$CSPT_UID" ]; then
                    echo "未输入财神用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh CSPT_UID "$CSPT_UID"
            fi
            CSPT_PASSKEY=$(`dirname $0`/get-args.sh CSPT_PASSKEY "财神密钥" )
            if [ -z "$CSPT_PASSKEY" ]; then
                read -p "请输入财神密钥:" CSPT_PASSKEY
                if [ -z "$CSPT_PASSKEY" ]; then
                    echo "未输入财神密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh CSPT_PASSKEY "$CSPT_PASSKEY"
            fi
            auth_site_str="-e CSPT_UID=${CSPT_UID} -e CSPT_PASSKEY=${CSPT_PASSKEY}"
            ;;
        tmpt)
            TMPT_UID=$(`dirname $0`/get-args.sh TMPT_UID "唐门用户ID" )
            if [ -z "$TMPT_UID" ]; then
                read -p "请输入唐门用户ID:" TMPT_UID
                if [ -z "$TMPT_UID" ]; then
                    echo "未输入唐门用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh TMPT_UID "$TMPT_UID"
            fi
            TMPT_PASSKEY=$(`dirname $0`/get-args.sh TMPT_PASSKEY "唐门密钥" )
            if [ -z "$TMPT_PASSKEY" ]; then
                read -p "请输入唐门密钥:" TMPT_PASSKEY
                if [ -z "$TMPT_PASSKEY" ]; then
                    echo "未输入唐门密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh TMPT_PASSKEY "$TMPT_PASSKEY"
            fi
            auth_site_str="-e TMPT_UID=${TMPT_UID} -e TMPT_PASSKEY=${TMPT_PASSKEY}"
            ;;
        raingfh)
            RAINGFH_UID=$(`dirname $0`/get-args.sh RAINGFH_UID "雨用户ID" )
            if [ -z "$RAINGFH_UID" ]; then
                read -p "请输入雨用户ID:" RAINGFH_UID
                if [ -z "$RAINGFH_UID" ]; then
                    echo "未输入雨用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh RAINGFH_UID "$RAINGFH_UID"
            fi
            RAINGFH_PASSKEY=$(`dirname $0`/get-args.sh RAINGFH_PASSKEY "雨密钥" )
            if [ -z "$RAINGFH_PASSKEY" ]; then
                read -p "请输入雨密钥:" RAINGFH_PASSKEY
                if [ -z "$RAINGFH_PASSKEY" ]; then
                    echo "未输入雨密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh RAINGFH_PASSKEY "$RAINGFH_PASSKEY"
            fi
            auth_site_str="-e RAINGFH_UID=${RAINGFH_UID} -e RAINGFH_PASSKEY=${RAINGFH_PASSKEY}"
            ;;
        gtkpw)
            GTKPW_UID=$(`dirname $0`/get-args.sh GTKPW_UID "GTK用户ID" )
            if [ -z "$GTKPW_UID" ]; then
                read -p "请输入GTK用户ID:" GTKPW_UID
                if [ -z "$GTKPW_UID" ]; then
                    echo "未输入GTK用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh GTKPW_UID "$GTKPW_UID"
            fi
            GTKPW_PASSKEY=$(`dirname $0`/get-args.sh GTKPW_PASSKEY "GTK密钥" )
            if [ -z "$GTKPW_PASSKEY" ]; then
                read -p "请输入GTK密钥:" GTKPW_PASSKEY
                if [ -z "$GTKPW_PASSKEY" ]; then
                    echo "未输入GTK密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh GTKPW_PASSKEY "$GTKPW_PASSKEY"
            fi
            auth_site_str="-e GTKPW_UID=${GTKPW_UID} -e GTKPW_PASSKEY=${GTKPW_PASSKEY}"
            ;;
        ptlgs)
            PTLGS_UID=$(`dirname $0`/get-args.sh PTLGS_UID "PTLGS用户ID" )
            if [ -z "$PTLGS_UID" ]; then
                read -p "请输入PTLGS用户ID:" PTLGS_UID
                if [ -z "$PTLGS_UID" ]; then
                    echo "未输入PTLGS用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTLGS_UID "$PTLGS_UID"
            fi
            PTLGS_PASSKEY=$(`dirname $0`/get-args.sh PTLGS_PASSKEY "PTLGS密钥" )
            if [ -z "$PTLGS_PASSKEY" ]; then
                read -p "请输入PTLGS密钥:" PTLGS_PASSKEY
                if [ -z "$PTLGS_PASSKEY" ]; then
                    echo "未输入PTLGS密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh PTLGS_PASSKEY "$PTLGS_PASSKEY"
            fi
            auth_site_str="-e PTLGS_UID=${PTLGS_UID} -e PTLGS_PASSKEY=${PTLGS_PASSKEY}"
            ;;
        hdbao)
            HDBAO_UID=$(`dirname $0`/get-args.sh HDBAO_UID "HDbao用户ID" )
            if [ -z "$HDBAO_UID" ]; then
                read -p "请输入HDbao用户ID:" HDBAO_UID
                if [ -z "$HDBAO_UID" ]; then
                    echo "未输入HDbao用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDBAO_UID "$HDBAO_UID"
            fi
            HDBAO_PASSKEY=$(`dirname $0`/get-args.sh HDBAO_PASSKEY "HDbao密钥" )
            if [ -z "$HDBAO_PASSKEY" ]; then
                read -p "请输入HDbao密钥:" HDBAO_PASSKEY
                if [ -z "$HDBAO_PASSKEY" ]; then
                    echo "未输入HDbao密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh HDBAO_PASSKEY "$HDBAO_PASSKEY"
            fi
            auth_site_str="-e HDBAO_UID=${HDBAO_UID} -e HDBAO_PASSKEY=${HDBAO_PASSKEY}"
            ;;
        sewerpt)
            # 下水道
            SEWERPT_UID=$(`dirname $0`/get-args.sh SEWERPT_UID "下水道用户ID" )
            if [ -z "$SEWERPT_UID" ]; then
                read -p "请输入下水道用户ID:" SEWERPT_UID
                if [ -z "$SEWERPT_UID" ]; then
                    echo "未输入下水道用户ID，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh SEWERPT_UID "$SEWERPT_UID"
            fi
            SEWERPT_PASSKEY=$(`dirname $0`/get-args.sh SEWERPT_PASSKEY "下水道密钥" )
            if [ -z "$SEWERPT_PASSKEY" ]; then
                read -p "请输入下水道密钥:" SEWERPT_PASSKEY
                if [ -z "$SEWERPT_PASSKEY" ]; then
                    echo "未输入下水道密钥，退出安装。"
                    exit 1
                fi
                `dirname $0`/set-args.sh SEWERPT_PASSKEY "$SEWERPT_PASSKEY"
            fi
            auth_site_str="-e SEWERPT_UID=${SEWERPT_UID} -e SEWERPT_PASSKEY=${SEWERPT_PASSKEY}"
            ;;
        *)
            echo "未输入认证站点，退出安装。"
            exit 1
            ;;
    esac
}

MOVIE_IS_ENV_AUTH_SITE=$(`dirname $0`/get-args.sh MOVIE_IS_ENV_AUTH_SITE "是否在环境变量中配置认证站点，请输入y/n：" )
 if [ -z "$MOVIE_IS_ENV_AUTH_SITE" ]; then
    echo "默认使用环境变量"
    MOVIE_IS_ENV_AUTH_SITE="y"
    `dirname $0`/set-args.sh MOVIE_IS_ENV_AUTH_SITE "$MOVIE_IS_ENV_AUTH_SITE"
fi
case $MOVIE_IS_ENV_AUTH_SITE in
    y)
        set_auth_site
        ;;
    n)
        ;;
    *)
esac
MOVIEPILOT_USE_GITHUB_ACCESS_TOKEN=$(`dirname $0`/get-args.sh MOVIEPILOT_USE_GITHUB_ACCESS "是否使用Github Access Token，请输入y/n：" )
 if [ -z "$MOVIEPILOT_USE_GITHUB_ACCESS_TOKEN" ]; then
    read -p "是否使用Github Access Token，请输入y/n：" MOVIEPILOT_USE_GITHUB_ACCESS_TOKEN
    if [ -z "$MOVIEPILOT_USE_GITHUB_ACCESS_TOKEN" ]; then
        echo "默认不使用Github Access Token"
        MOVIEPILOT_USE_GITHUB_ACCESS
        MOVIEPILOT_USE_GITHUB_ACCESS_TOKEN="n"
    fi
    `dirname $0`/set-args.sh MOVIEPILOT_USE_GITHUB_ACCESS_TOKEN "$MOVIEPILOT_USE_GITHUB_ACCESS_TOKEN"
fi

if [ "$MOVIEPILOT_USE_GITHUB_ACCESS"="y" ]; then
    GITHUB_READ_ACCESS_TOKEN=$(`dirname $0`/get-args.sh GITHUB_READ_ACCESS_TOKEN "具有可读权限的Github Access Token" )
    if [ -z "$GITHUB_READ_ACCESS_TOKEN" ]; then
        read -p "请输入具有可读权限的Github Access Token:" GITHUB_READ_ACCESS_TOKEN
        if [ -z "$GITHUB_READ_ACCESS_TOKEN" ]; then
            echo "未输入Github Access Token，退出安装。"
            exit 1
        fi
        `dirname $0`/set-args.sh GITHUB_READ_ACCESS_TOKEN "$GITHUB_READ_ACCESS_TOKEN"
    fi
fi

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
`if [ $MOVIEPILOT_USE_GITHUB_ACCESS="y" ]; then echo "-e GITHUB_TOKEN=${GITHUB_READ_ACCESS_TOKEN}"; fi` \
`if [ $MOVIE_IS_ENV_AUTH_SITE = "y" ]; then echo "-e AUTH_SITE=${MOVIEPILOT_AUTH_SITE} ${auth_site_str}"; fi` \
--network=$docker_network_name --network-alias=${container_name} --hostname=${container_name} \
-v $base_data_dir/${container_name}-v2/config:/config \
-v $base_data_dir/public/:/data \
-v $base_data_dir/${container_name}-v2/core:/moviepilot/.cache/ms-playwright \
-v /var/run/docker.sock:/var/run/docker.sock:ro \
--label "traefik.enable=true" \
--label 'traefik.http.routers.'${container_name}'.rule=Host(`'${container_name}.$domain'`)' \
--label "traefik.http.routers.${container_name}.tls=${tls}" \
--label "traefik.http.routers.${container_name}.tls.certresolver=traefik" \
--label "traefik.http.routers.${container_name}.tls.domains[0].main=*.$domain" \
--label "traefik.http.services.${container_name}.loadbalancer.server.port=${port}" \
${image}