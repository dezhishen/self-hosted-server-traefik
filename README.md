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

| 特性 | 说明 |
|------|------|
| 一键安装 | 交互式配置，参数自动保存 `~/.args/`，再次运行无需重复输入 |
| 网络 | bridge / macvlan / internal 三种模式 |
| 代理 | Traefik 自动路由 + Let's Encrypt TLS |
| 容器互通 | 容器名互访，跨网络适配 |

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








