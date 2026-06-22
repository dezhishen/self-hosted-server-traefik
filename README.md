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
#### 1.1.1 网络模式
- 大部分服务使用`bridge`**模式**网络，默认使用`traefik`网络
- 部分服务使用`host`网络(如：qbittorrent等依赖host网络构建upnp映射的服务)
- **xiaoya相关服务的网络模式由xiaoya官方脚本决定**，但因xiaoya容器均有端口映射，其他容器如需访问，可按照`host`网络方法进行访问
#### 1.1.2 桥接网络容器之间访问
通过容器名进行访问，如在moviepilot容器内，访问jellyfin为`http://jellyfin:8096`
#### 1.1.3 桥接网络内的容器访问host模式的容器
桥接网络容器访问宿主机的服务，则使用`traefik`网络的网关地址进行访问，通过如下命令可以获取网关地址
```bash
docker network inspect traefik --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' | awk -F'.' '{print $1"."$2"."$3"."1}'
```
- 假设上面的地址输出的网络为`172.18.0.1`,moviepilot容器需要访问宿主机的qbittorrent服务，则使用`http://172.18.0.1:8080`进行访问
#### 1.1.4 host网络容器访问桥接网络内的容器
host网络的容器无法直接访问桥接网络内的容器，需要使用域名访问，如在qbittorrent容器内，webhook到moviepilot容器，则使用`http(s)://moviepilot.${domain}`进行访问

#### 1.1.5 host网络之间访问
- 直接使用宿主机ip访问
- 使用域名地址访问

#### 1.1.6 内部网络（internal network）
内部网络是一种特殊的 `bridge` 网络，创建时带有 `--internal` 标志，**容器只能与同网络内的其他容器通信，无法访问外网**，适合对安全隔离有要求的服务（如数据库）。

**使用场景：**
- `mariadb`、`postgres`、`redis` 等数据库服务加入内部网络后，仅允许同网络内的应用容器访问，避免数据库直接暴露
- `vaultwarden` 等对安全性要求较高的服务可加入内部网络

**创建内部网络：**
```bash
sh scripts/create-docker-internal-network.sh
```

**容器间访问：**
与普通 bridge 网络相同，通过容器名进行访问，如应用容器访问 mariadb：
```
host: mariadb
port: 3306
```

> **注意：** 加入内部网络的容器同时也连接了 `traefik` 网络，因此 traefik 仍可对其进行路由，内部网络仅限制容器对外网的直接访问。

#### 1.1.7 macvlan 网络
macvlan 网络让容器拥有独立的 MAC 地址，**直接接入物理网络，表现得像局域网内一台独立的物理机**，适合需要独占端口或使用 UPnP/NAT-PMP 等依赖真实 IP 的服务（如 qbittorrent、transmission）。

**使用场景：**
- `qbittorrent`、`transmission` 等 BT 下载工具需要固定 IP 并对外广播端口时，建议使用 macvlan
- 需要服务在局域网内以独立 IP 出现，与宿主机 IP 相互隔离

**创建 macvlan 网络：**
```bash
sh scripts/create-docker-macvlan-network.sh
```
> 创建时会自动读取宿主机默认网卡、子网、网关信息，并支持同步创建用于**宿主机与 macvlan 容器通信**的转发接口（`${网络名}_forward`），通过 systemd 服务保证重启后自动生效。

**宿主机与 macvlan 容器互访：**

macvlan 的限制是宿主机默认无法直接访问 macvlan 容器，需要额外创建一个同名的 macvlan 子接口（`${网络名}_forward`）并配置路由来解决：
- 创建 macvlan 网络时选择"创建与宿主机通信的 macvlan 网络"，并为转发接口分配一个局域网内未被占用的 IP
- 脚本会通过 systemd 服务在重启后自动重建该接口和路由

**traefik 代理 macvlan 容器：**

macvlan 容器不在 `traefik` bridge 网络内，traefik 通过容器的 macvlan IP 直接代理。安装脚本会自动：
1. 为容器分配一个固定的 macvlan IP（记录在 `.args/DOCKER_MACVLAN_IPS`）
2. 在 traefik 的 providers 目录生成对应的静态配置文件
3. 在宿主机添加到该 IP 的路由（via `${网络名}_forward` 接口）

**网络拓扑说明：**
```
物理网络 (LAN)
  ├── 宿主机 (eth0)
  ├── macvlan 转发接口 (macvlan_forward) ← 宿主机与 macvlan 容器互通
  └── macvlan 容器 (qbittorrent / transmission) ← 独立 IP，直接在 LAN 内可见
```

> **注意：** macvlan 容器与宿主机同物理网卡的流量受 macvlan 内核限制，宿主机无法通过 `eth0` 直接访问 macvlan 容器，必须通过 `${网络名}_forward` 子接口转发。

### 1.2 部署后目录结构
**部署后的文件，大多数的权限是，当前用户和当前用户组，如果部分容器出现权限不足的情况，请查看和修改对应目录的权限**
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
.... #其他服务
---/xiaoya
------/root
--------/data # xiaoya-alist配置目录
------/emby
--------/media # xiaoya-emby配置目录
```
### 1.3 容器之间挂载目录结构
> 部分情况下，容器之间需要共享数据，如：
- iyuu容器需要挂载qbittorrent和transmission的目录

> 假设A容器需要挂载B容器的目录，则B容器的所有挂载目录在A容器中都存在于 `/A` 目录下：
- 如iyuu容器需要挂载qbittorrent的目录，则在iyuu容器内，访问qbittorrent的路径为`/qbittorrent/`

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
如果需要外网访问，则需要安装cloudflared，ps:部分服务依赖https，如果不需要外网访问（如使用异地组网），可以考虑使用
[~~nip~~](https://nip.io/)，ps:nip与traefik的证书问题暂未解决。
```bash
    sh install-one.sh cloudflared
```
### 2.3 使用说明
使用 sh install-one.sh 服务名 安装服务，如：
- 安装qbittorrent
```bash
    sh install-one.sh qbittorrent
```
- 安装alist
```bash
    sh install-one.sh alist
```

### 2.4 推荐服务
#### 2.4.1 备份工具[duplicati](https://www.duplicati.com/)
配合alist使用，借助alist的webdav功能，可以实现备份到网盘
```bash
    # 安装duplicati
    sh install-one.sh duplicati
    # 安装alist
    sh install-one.sh alist
```     
#### 2.4.2 密码管理器[vaultwarden](https://github.com/dani-garcia/vaultwarden)
```bash
    sh install-one.sh vaultwarden
```
### 2.5 安装[xiaoya](https://github.com/DDS-Derek/xiaoya-alist)
#### 2.5.1 执行xiaoya脚本
```bash
    sh xiaoya.sh
```
#### 2.5.2 创建traefik配置文件
```bash
    sh xiaoya-traefik.sh
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
> 将会排除xiaoya相关的容器
```bash
    sh update.sh
```
##### 3.2.2 更新单个容器
```bash
    sh update-one.sh 容器名
```
### 4.部分容器设置
#### 4.1 qbittorrent
设置名|配置项|说明
---|---|---
下载/默认保存路径|/data/downloads|下载目录**其他分类目录务必设置在`/data/`下**
下载/保存未完成的torrent到|/incomplete-torrents|未完成的种子目录
下载/保存完成的torrent到|/finished-torrents|完成的种子目录
连接/监听端口/使用我的路由器的UPnP/NAT-PMP|true|使用路由器的UPnP/NAT-PMP功能，自动映射端口
BitTorrent/隐私/加密模式|强制加密|强制加密，防止ISP限速
#### 4.2 jellyfin
设置名|配置项|说明
---|---|---
媒体库路径|/data/${xxx}|媒体库路径，务必设置在**`/data/`**下
媒体库/元数据存储方式|NFO|使用NFO文件存储元数据，由于元数据均为外部生成，并且存在NFO文件中，所以使用NFO存储元数据
#### 4.3 transmission
> ps 一般使用transmission做为iyuu的辅种器，使用qbittorrent做为主种子器

设置名|配置项|说明
---|---|---
Torrents/Downloading/Download to|/data/downloads|下载目录，务必设置在**`/data/`**下
Torrents/Downloading/Use temporary directory|/incomplete-torrents|未完成的种子目录
Peers/Options/Encryption|Require encryption|强制加密，防止ISP限速
Network/Use port forwarding from my router|true|使用路由器的UPnP/NAT-PMP功能，自动映射端口
Network/Options/Enable uTP for peer connections|true|启用uTP协议，减少ISP限速
#### 4.4 iyuu
##### 4.4.1 数据库配置
- 如果使用外部数据库，才需要配置，**在安装界面进行配置**

配置项|配置值|说明
---|---|---
数据库用户|root|可以自行在mariaDB中创建用户
数据库密码|在脚本.args/MYSQL_PASSWORD中获取|可以自行在mariaDB中创建用户和对应的密码
数据库|iyuu|必须手动创建，脚本不会自动创建
数据库HOST|mariadb|数据库的容器名
数据库端口|3306|数据库的端口
##### 4.4.2 qbittorrent配置
配置项|配置值|说明
---|---|---
协议主机|http://${宿主机ip}:8080|qbittorrent的地址，注意：需要使用宿主机ip，不能使用容器名，也可以使用网络traefik的网关地址，获取方式为`docker network inspect traefik --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' | awk -F'.' '{print $1"."$2"."$3"."1}'`
种子文件夹|/qbittorrent/config/qBittorrent/BT_backup|qbittorrent的完成种子目录
默认下载器|true|使用qbittorrent做为下载器

##### 4.4.3 transmission配置
配置项|配置值|说明
---|---|---
协议主机|http://${宿主机ip}:9091|transmission的地址，注意：需要使用宿主机ip，不能使用容器名，也可以使用网络traefik的网关地址，获取方式为`docker network inspect traefik --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' | awk -F'.' '{print $1"."$2"."$3"."1}'`
接入点|/transmission/rpc|transmission的rpc地址
种子文件夹|/transmission/config/torrents|transmission的完成种子目录
校验后做种|true|校验完成后做种
默认下载器|**false**|不使用transmission做为下载器

##### 4.4.4 自动转移任务配置
###### 4.4.4.1 开始创建任务
- 1.进入目录**计划任务/任务管理**
- 2.点击**自动转移**按钮
- 3.点击**添加任务**按钮
###### 4.4.4.2 任务配置

配置项|配置值|说明
-|-|-
任务标题|qb-tr-自动转移|可以自己取，但是建议使用qb-tr-开头，方便后续查找
执行周期|N小时|可以自行选择，建议使用每N小时
来源下载器|qbittorrent|使用qbittorrent做为主下载器
目标下载器|transmission|使用transmission做为辅下载器
标记规则|标记标签|使用标记规则，方便后续查找
路径转换类型|相等|由于本项目安装时，已经完成了路径转换，所以使用相等
跳校验|NO|自动校验，建议开启
暂停|NO|不暂停任务，直接开始做种
删除源做种|NO|转移后，删除来源下载器内的种子，**风险提示：第一次转移时请不要勾选，万一路径配置错误，将会删除客户端正常做种的种子。非必要，请勿勾选！！！**
排序|0|默认排序
启用|true|启用任务

##### 4.4.5 自动辅种任务配置

###### 4.4.5.1 开始创建任务
- 1.进入目录**计划任务/任务管理**
- 2.点击**自动辅种**按钮
- 3.点击**添加任务**按钮
###### 4.4.5.2 任务配置（未开启自动转移的任务）
> **假如开启自动转移的任务，按照下面的配置，否则按照另外一个**

配置项|配置值|说明
---|---|---
任务标题|qb-tr-自动辅种|可以自己取，但是建议使用qb-tr-开头，方便后续查找
执行周期|N小时|可以自行选择，建议使用每N小时
辅种站点|全选
辅种下载器|qbittorrent|使用qbittorrent做为下载器
主辅分离|transmission|使用主辅分离，降低对主种子器的影响
路径过滤器|留空|默认辅种所有种子，可以自行选择
通知渠道|爱语飞飞|使用爱语飞飞做为通知渠道，其他的可以自行选择
标记规则|标记标签|使用标记规则，方便后续查找
自动校验|On|自动校验，建议开启
排序|0|默认排序
启用|true|启用任务

###### 4.4.5.3 任务配置（开启自动转移的任务）
> **假如开启自动转移的任务，按照下面的配置，否则按照另外一个**

配置项|配置值|说明
---|---|---
任务标题|tr-tr-自动辅种|可以自己取，但是建议使用tr-tr-开头，方便后续查找
执行周期|N小时|可以自行选择，建议使用每N小时
辅种站点|全选
辅种下载器|transmission|使用transmission做为下载器
主辅分离|transmission|使用主辅分离，降低对主种子器的影响
路径过滤器|留空|默认辅种所有种子，可以自行选择
通知渠道|爱语飞飞|使用爱语飞飞做为通知渠道，其他的可以自行选择
标记规则|标记标签|使用标记规则，方便后续查找
自动校验|On|自动校验，建议开启
排序|0|默认排序
启用|true|启用任务







