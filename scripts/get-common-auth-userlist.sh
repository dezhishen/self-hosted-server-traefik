#!/bin/bash
function get_common_auth_userlist() {
    COMMON_AUTH_USER=$(`dirname $0`/get-args.sh COMMON_AUTH_USER 用户名)
    if [ -z "$COMMON_AUTH_USER" ]; then
        read -p "请输入用户名:" COMMON_AUTH_USER
        if [ -z "$COMMON_AUTH_USER" ]; then
            echo "用户名使用默认值: admin"
            COMMON_AUTH_USER="admin"
        fi
        `dirname $0`/set-args.sh COMMON_AUTH_USER "$COMMON_AUTH_USER"
    fi

    COMMON_AUTH_PASSWORD=$(`dirname $0`/get-args.sh COMMON_AUTH_PASSWORD 密码)
    if [ -z "$COMMON_AUTH_PASSWORD" ]; then
        read -p "请输入密码:" COMMON_AUTH_PASSWORD
        if [ -z "$COMMON_AUTH_PASSWORD" ]; then
            echo "随机生成密码"
            COMMON_AUTH_PASSWORD=`$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)`
        fi
        `dirname $0`/set-args.sh COMMON_AUTH_PASSWORD "$COMMON_AUTH_PASSWORD"
    fi
    #echo "用户名: $COMMON_AUTH_USER"
    #echo "密码: $COMMON_AUTH_PASSWORD"
    digest="$(printf "%s:%s:%s" "$COMMON_AUTH_USER" "traefik" "$COMMON_AUTH_PASSWORD" | md5sum | awk '{print $1}' )"
    userlist=$(printf "%s:%s:%s\n" "$COMMON_AUTH_USER" "traefik" "$digest")
    echo $userlist
    exit 0
}
echo $(get_common_auth_userlist)

