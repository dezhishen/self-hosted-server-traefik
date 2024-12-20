# self-hosted-server-traefik
本项目为基于traefik代理的私有化部署脚本

[![](https://img.shields.io/github/license/dezhishen/self-hosted-server-traefik.svg?style=for-the-badge&logo=github)](./LICENSE)
[![](https://img.shields.io/github/stars/dezhishen/self-hosted-server-traefik.svg?style=for-the-badge&logo=github)](https://github.com/dezhishen/self-hosted-server-traefik/stargazers)
[![](https://img.shields.io/github/forks/dezhishen/self-hosted-server-traefik.svg?style=for-the-badge&logo=github)](https://github.com/dezhishen/self-hosted-server-traefik/network/members)
[![](https://img.shields.io/github/contributors/dezhishen/self-hosted-server-traefik.svg?style=for-the-badge&logo=github)](https://github.com/dezhishen/self-hosted-server-traefik/graphs/contributors)

[![](https://img.shields.io/github/commit-activity/m/dezhishen/self-hosted-server-traefik?logo=github&style=for-the-badge)](https://github.com/dezhishen/self-hosted-server-traefik/graphs/commit-activity)
[![](https://img.shields.io/github/last-commit/dezhishen/self-hosted-server-traefik.svg?style=for-the-badge&logo=github)](https://github.com/dezhishen/self-hosted-server-traefik/commits)

[![](https://img.shields.io/static/v1?label=&message=Docker&style=for-the-badge&color=blue&logo=Docker)](https://www.docker.com/)
[![](https://img.shields.io/static/v1?label=&message=traefik&style=for-the-badge&color=blue&logo=Traefik%20Mesh)](https://github.com/traefik/traefik/)
[![](https://img.shields.io/static/v1?label=&message=cloudflare&style=for-the-badge&color=blue&logo=Cloudflare)](https://www.cloudflare.com/)
## 1 项目目标
基于`traefik`做为反向代理，基于`cloudflared tunnel`实现外网访问的私有化部署解决方案脚本
### 1.1 网络
- 大部分服务使用`bridge`网络
- 部分服务使用`host`网络(如：qbittorrent等依赖host网络构建upnp映射的服务)
### 1.2 部署后目录结构
```
/$base_data_dir/
---/public/ # 公共数据目录
------/movie/ # 电影
------/tv/ # 电视剧
------/music/ # 音乐
------/... # 其他
---/traefik/ # traefik配置目录
---/cloudflared/ # cloudflared配置目录
---/rss-bot/ # rss机器人配置目录
---/vaultwarden/ # 密码管理器配置目录
---/ttyd/ # ttyd配置目录
---/duplicati/ # 备份工具配置目录
```
## 2 快速开始
### 2.1 前置条件
- 安装docker
  - 参考[docker安装](https://docs.docker.com/engine/install/)
- 准备域名且托管到cloudflare（可选）
  - 参考[cloudflare](https://www.cloudflare.com/)
- 拉取本项目
  - git clone https://github.com/dezhishen/self-hosted-server-traefik.git
  - 或者直接下载[zip](https://github.com/dezhishen/self-hosted-server-traefik/archive/refs/heads/master.zip)
### 2.2 构建网络环境
#### 2.2.1 安装traefik(必选)
```bash
    sh install-one.sh traefik
```
#### 2.2.2 安装cloudflared(可选)
如果需要外网访问，则需要安装cloudflared，ps:部分服务依赖https，如果不需要外网访问（如使用异地组网），可以考虑使用[noip](https://nip.io/)。
```bash
    sh install-one.sh cloudflared
```
### 2.3 推荐服务
#### 2.3.1 备份工具[duplicati](https://www.duplicati.com/)
配合alist使用，借助alist的webdav功能，可以实现备份到网盘
```bash
    # 安装duplicati
    sh install-one.sh duplicati
    # 安装alist
    sh install-one.sh alist
```     
#### 2.3.2 密码管理器[vaultwarden](https://github.com/dani-garcia/vaultwarden)
```bash
    sh install-one.sh vaultwarden
```
### 2.4 安装[xiaoya](https://github.com/DDS-Derek/xiaoya-alist)
```bash
    sh xiaoya.sh
```

### 3 工具
#### 3.1 更新本项目
```bash
    sh update-self.sh
```
或者
```bash
    git pull
```
#### 3.2 更新容器
##### 3.2.1 更新所有容器
```bash
    sh update.sh
```
##### 3.2.2 更新单个容器
```bash
    sh update-one.sh 容器名
```

