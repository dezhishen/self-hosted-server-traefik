#! /bin/bash
dir=$1

if [ ! -d $dir ];then
    mkdir $dir
    printf "创建目录: %s" $dir
    echo ""
else
    printf "目录已存在: %s" $dir
    echo ""
fi