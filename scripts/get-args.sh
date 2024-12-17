#! /bin/bash
arg_name=$1
msg=$2
# 如果目录.args不存在,则创建
if [ ! -d "`dirname $0`/../.args" ]; then
    mkdir `dirname $0`/../.args
fi

if [ ! -f `dirname $0`/../.args/$arg_name ]; then
    echo ""
    exit 0
fi
value=$(cat `dirname $0`/../.args/$arg_name)
if [ -z "$value" ]; then
    echo ""
    exit 0
fi
text=$(printf "如果你想修改[%s]的值[%s]，请输入，否则请直接回车:" "$msg" "$value")
read -p "$text" new_value
if [ ! -z "$new_value" ]; then
    value=$new_value
    `dirname $0`/set-args.sh $arg_name $new_value
fi
echo "$value"
exit 0