#! /bin/bash
arg_name=$1
value=$2
homedir=${HOME}
# 如果目录.args不存在,则创建
if [ ! -d "${homedir}/.args" ]; then
    mkdir ${homedir}/.args
fi
echo "$value" > ${homedir}/.args/$arg_name