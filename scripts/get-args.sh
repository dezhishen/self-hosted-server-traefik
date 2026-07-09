#! /bin/bash
arg_name=$1
msg=$2
homedir=${HOME}
# 如果目录.args不存在,则创建
if [ ! -d "${homedir}/.args" ]; then
    mkdir -p ${homedir}/.args
fi

if [ ! -f ${homedir}/.args/$arg_name ]; then
    echo ""
    exit 0
fi
value=$(cat ${homedir}/.args/$arg_name)
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