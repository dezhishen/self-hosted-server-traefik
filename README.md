# self-hosted-server-traefik

[![License](https://img.shields.io/github/license/dezhishen/self-hosted-server-traefik)](./LICENSE)
[![CI](https://github.com/dezhishen/self-hosted-server-traefik/actions/workflows/ci.yml/badge.svg)](https://github.com/dezhishen/self-hosted-server-traefik/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/dezhishen/self-hosted-server-traefik)](https://github.com/dezhishen/self-hosted-server-traefik/releases)
[![Go Report Card](https://goreportcard.com/badge/github.com/dezhishen/self-hosted-server-traefik)](https://goreportcard.com/report/github.com/dezhishen/self-hosted-server-traefik)

Docker + Traefik 私有化部署 —— 交互式一键安装 40+ 自托管服务，带 Web 管理面板。

## Quick Start

```bash
git clone git@github.com:dezhishen/self-hosted-server-traefik.git
cd self-hosted-server-traefik

# CLI 模式
./bin/selfhosted -c selfhosted.yaml install traefik

# Web 面板
./bin/selfhosted -c selfhosted.yaml serve
```

> 旧版 bash 脚本已迁移至 [`shell`](https://github.com/dezhishen/self-hosted-server-traefik/tree/shell) 分支。

## Features

- **一键安装** 40+ 自托管服务，交互式参数配置，自动持久化 (`~/.args/`)
- **Web 管理面板** 使用 Vue 3 + Element Plus，内嵌于 Go 二进制
- **多容器运行时** 支持 Docker / Podman，本地或远程 (unix/tcp/ssh)
- **订阅同步** 从远程 registry 拉取社区服务定义
- **类型化参数** string / password(加密) / bool / number / select / array
- **Managed Labels** 统一标签管理 (`selfhosted.*`)
- **多模块架构** `contracts` → `backend` → `sdk` → `cli`

## Installation

### 从 Release 下载

从 [Releases](https://github.com/dezhishen/self-hosted-server-traefik/releases) 下载对应平台的二进制。

```bash
chmod +x selfhosted
./selfhosted help
```

### Docker

```bash
docker pull ghcr.io/dezhishen/self-hosted-server-traefik/cli:latest
docker run --rm ghcr.io/dezhishen/self-hosted-server-traefik/cli:latest help
```

### 从源码构建

```bash
make build        # 构建 CLI（含前端）
make build-backend # 仅后端
make test         # 运行测试
```

## Usage

```bash
# 查看可用服务
selfhosted list

# 安装服务
selfhosted -c selfhosted.yaml install traefik

# 带参数安装
selfhosted install jellyfin --param jellyfin_port=8096

# 启动 Web 面板
selfhosted -c selfhosted.yaml serve

# 管理订阅
selfhosted sub add community https://example.com/templates

# 管理远程主机
selfhosted remote add myserver ssh://user@host
```

### Configuration

参考 [`selfhosted.example.yaml`](selfhosted.example.yaml):

```yaml
config_path: ~/.args
engine: docker

remotes:
  - name: myserver
    type: ssh
    host: user@192.168.1.100

subscriptions:
  - name: community
    url: https://example.com/templates
```

## Services

| 分类 | 服务 |
|------|------|
| **Proxy** | traefik, nginx |
| **Media** | jellyfin, plex, emby, xiaoya |
| **Download** | qbittorrent, transmission, aria2 |
| **Database** | postgres, mysql, mariadb, redis, mongodb |
| **Dashboard** | homepage, homer, dashy, organizr |
| **Monitoring** | prometheus, grafana, node-exporter |
| **Storage** | minio, nextcloud, seafile |
| **Auth** | authelia, authentik, keycloak |
| **Dev Tools** | gitlab, jenkins, gitea |
| ... | 共 65+ 服务 |

## Architecture

```
               ┌─────────┐
               │  CLI    │ ← ─ ─ embed ─ ─ ─ ─ Frontend
               │  (Go)   │                     (Vue 3)
               └────┬────┘
                    │
               ┌────▼────┐
               │  SDK    │
               │  (Go)   │
               └────┬────┘
                    │
          ┌─────────┼─────────┐
          │         │         │
   ┌──────▼──┐ ┌───▼────┐ ┌──▼──────┐
   │Contract │ │ Backend│ │ Remote  │
   │(interf) │ │ (impl) │ │ Registry│
   └─────────┘ └───┬────┘ └─────────┘
                   │
          ┌────────┼────────┐
          │        │        │
     ┌────▼──┐ ┌──▼───┐ ┌──▼───┐
     │Docker │ │Podman│ │~/.args│
     └───────┘ └──────┘ └──────┘
```

详细架构 → [docs/architecture.md](docs/architecture.md)

## Development

```bash
make dev-frontend   # 前端热重载
make dev            # CLI 调试
make test           # Go 测试
make test-e2e       # Playwright E2E
```

详见 [docs/development.md](docs/development.md)

## License

[MIT](LICENSE)
