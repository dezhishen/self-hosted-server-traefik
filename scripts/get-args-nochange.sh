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
echo "$value"
exit 0