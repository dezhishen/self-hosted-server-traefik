#!/bin/bash
# 判断 /etc/DDSRem 目录是否存在，不存在则创建
echo "开始准备工作..."
if [ ! -d "/etc/DDSRem" ]; then
    sudo mkdir -p /etc/DDSRem
fi
base_data_dir=`./scripts/get-args.sh base_data_dir "数据目录(如 /docker_data)"`
if [ -z "$base_data_dir" ]; then
    read -p "请输入数据目录(如 /docker_data):" base_data_dir
    if [ -z "$base_data_dir" ]; then
        echo "数据目录为空,使用默认值 /docker_data"
        base_data_dir=/docker_data
    fi
    ./scripts/set-args.sh base_data_dir $base_data_dir
    echo "文件不存在，创建文件且设置权限"
    sudo mkdir -p $base_data_dir
    sudo chown -R `id -u`:`id -g` $base_data_dir
fi
# 判断 /etc/DDSRem/xiaoya_alist_config_dir.txt 文件是否存在，不存在则创建，文件内容为 ${base_data_dir}/xiaoya/root/data
echo "预设xiaoya_alist的配置目录为 ${base_data_dir}/xiaoya/root/data"
if [ ! -f "/etc/DDSRem/xiaoya_alist_config_dir.txt" ]; then
    sudo touch /etc/DDSRem/xiaoya_alist_config_dir.txt
    sudo sh -c "echo ${base_data_dir}/xiaoya/root/data > /etc/DDSRem/xiaoya_alist_config_dir.txt"
fi
echo "预设xiaoya_alist的媒体目录为 ${base_data_dir}/xiaoya/emby/media"
# 判断 /etc/DDSRem/xiaoya_alist_media_dir.txt 文件是否存在，不存在则创建，文件内容为 ${base_data_dir}/xiaoya/emby/media
if [ ! -f "/etc/DDSRem/xiaoya_alist_media_dir.txt" ]; then
    sudo touch /etc/DDSRem/xiaoya_alist_media_dir.txt
    sudo sh -c "echo ${base_data_dir}/xiaoya/emby/media > /etc/DDSRem/xiaoya_alist_media_dir.txt"
fi
echo "即将执行xiaoya官方安装脚本"
sudo bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)"