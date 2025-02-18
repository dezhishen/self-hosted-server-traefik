#! /bin/bash
arg_name=$1
value=$2
# 如果目录.args不存在,则创建
if [ ! -d "`dirname $0`/../.args" ]; then
    mkdir `dirname $0`/../.args
fi
echo "$value" > `dirname $0`/../.args/$arg_name