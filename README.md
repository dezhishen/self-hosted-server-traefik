# self-hosted-server-traefik

[![License](https://img.shields.io/github/license/dezhishen/self-hosted-server-traefik)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/dezhishen/self-hosted-server-traefik)](https://github.com/dezhishen/self-hosted-server-traefik/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/dezhishen/self-hosted-server-traefik)](https://github.com/dezhishen/self-hosted-server-traefik/commits)

Docker + Traefik 私有化部署，交互式一键安装 40+ 服务。

## 快速开始

```bash
git clone git@github.com:dezhishen/self-hosted-server-traefik.git
cd self-hosted-server-traefik
./install-one.sh traefik      # 必选：反向代理
./install-one.sh jellyfin     # 安装任意服务
```

## 特性

### 一键安装
交互式配置，参数自动保存 `~/.args/`，再次运行无需重复输入。支持 bash 自动补全（`./bash-complete.sh install`）。

### 网络模式

| 模式 | 创建命令 | 适用场景 | 容器互通 |
|------|---------|---------|---------|
| **bridge** | `create-docker-bridge-network.sh` | 大部分服务 | 容器名互访 |
| **macvlan** | `create-docker-macvlan-network.sh` | 需独立 IP（BT 下载） | 通过 `macvlan_forward` 子接口与宿主机互通 |
| **internal** | `create-docker-internal-network.sh` | 数据库等需隔离 | 仅同网络内互通，阻隔外网 |

> macvlan 容器默认无法被宿主机直接访问。本项目的 macvlan 创建脚本会自动配置 `_forward` 子接口 + 静态路由 + systemd 持久化，解决宿主机与 macvlan 容器互通问题。

### 反向代理
Traefik 自动路由，bridge 模式用 Docker labels，macvlan 模式生成静态 provider 文件，TLS 自动签发续期。

### 关键脚本

| 脚本 | 用途 |
|------|------|
| `install-one.sh <服务>` | 统一安装入口，自动调用 `scripts/install-*.sh` |
| `scripts/install-*.sh` | 各服务安装脚本，交互式配置 + docker run |
| `scripts/create-docker-*-network.sh` | 创建 bridge / macvlan / internal 网络 |
| `scripts/create-traefik-provider*.sh` | 生成 Traefik 路由配置 |
| `scripts/get-args.sh / set-args.sh` | 参数持久化读写 |
| `scripts/stop-container.sh` | 停止并删除容器 |
| `update.sh / update-one.sh` | 更新全部/单个容器 |
| `update-self.sh` | git pull 更新项目 |
| `bash-complete.sh` | bash Tab 自动补全（动态扫描脚本目录） |
| `xiaoya.sh / xiaoya-traefik.sh` | xiaoya 媒体库安装 & Traefik 代理配置 |

## 目录

```
.
├── install-one.sh          # 入口
├── scripts/                # 安装 & 工具脚本
├── docker/                 # 定制镜像
├── docs/                   # 教程 & 容器指南
└── template/               # Traefik 配置模板
```

## 更多

- 教程 & 网络配置 → [docs/tutorials/](docs/tutorials/)
- 特定容器指南 → [docs/containers/](docs/containers/)
- 更新: `./update.sh` 或 `./update-one.sh <容器名>`








