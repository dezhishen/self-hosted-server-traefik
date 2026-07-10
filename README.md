# self-hosted-server-traefik

[![License](https://img.shields.io/github/license/dezhishen/self-hosted-server-traefik)](./LICENSE)
[![CI](https://github.com/dezhishen/self-hosted-server-traefik/actions/workflows/ci.yml/badge.svg)](https://github.com/dezhishen/self-hosted-server-traefik/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/dezhishen/self-hosted-server-traefik)](https://github.com/dezhishen/self-hosted-server-traefik/releases)
[![Go Report Card](https://goreportcard.com/badge/github.com/dezhishen/self-hosted-server-traefik)](https://goreportcard.com/report/github.com/dezhishen/self-hosted-server-traefik)

Docker + Traefik 私有化部署 —— 交互式一键安装 65+ 自托管服务，带 Web 管理面板。

> 旧版 bash 脚本已迁移至 [`shell`](https://github.com/dezhishen/self-hosted-server-traefik/tree/shell) 分支。

## Quick Start

```bash
# 1. 下载二进制
curl -L -o selfhosted https://github.com/dezhishen/self-hosted-server-traefik/releases/latest/download/selfhosted_linux_amd64.tar.gz
tar -xzf selfhosted_linux_amd64.tar.gz

# 2. 生成配置文件
cat > config.yaml <<EOF
endpoints:
  default:
    name: default
    default: true
    connection:
      type: unix
      endpoint: /var/run/docker.sock
EOF

# 3. 安装 Traefik 反向代理
./selfhosted -c config.yaml install traefik

# 4. 启动 Web 管理面板
./selfhosted -c config.yaml serve
# → 访问 http://localhost:8080
```

**Docker 一键运行：**
```bash
docker run -d --name selfhosted -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $PWD/config.yaml:/config.yaml \
  ghcr.io/dezhishen/self-hosted-server-traefik/cli:latest \
  -c /config.yaml serve
```

## Features

- **一键安装** 65+ 自托管服务（Traefik / Jellyfin / Homepage / ...），交互式参数配置
- **Web 管理面板** Vue 3 + Element Plus，内嵌于 Go 二进制，支持多端点切换
- **多容器运行时** Docker / Podman，本地或远程（unix/tcp/http/https/ssh）
- **TLS 连接** 支持远程 Docker API（Docker Proxy 风格），PEM 证书粘贴配置
- **订阅同步** 从 Git 仓库拉取社区服务模板
- **模板引擎** Go template 渲染容器参数，类型化参数（string/password/bool/number/select/array）
- **移动端自适应** 侧边栏折叠、卡片堆叠、表格横向滚动

## Installation

### 从 Release 下载

从 [Releases](https://github.com/dezhishen/self-hosted-server-traefik/releases) 下载对应平台二进制：
```bash
chmod +x selfhosted
./selfhosted help
```

### 从源码构建

```bash
git clone git@github.com:dezhishen/self-hosted-server-traefik.git
cd self-hosted-server-traefik
make build
```

## Usage

```bash
# 查看可用服务
selfhosted -c config.yaml list

# 安装服务
selfhosted -c config.yaml install jellyfin
selfhosted -c config.yaml install jellyfin --param jellyfin_port=8096

# 设置密码
selfhosted -c config.yaml passwd

# 启动 Web 面板
selfhosted -c config.yaml serve

# 管理订阅
selfhosted -c config.yaml sub add community https://github.com/user/repo
selfhosted -c config.yaml sub sync community

# 连接远程端点
selfhosted -c config.yaml remote add myserver tcp://192.168.1.100:2375
```

## Docs

| Document | Description |
|----------|-------------|
| [Usage](docs/usage.md) | Config file, CLI commands, service templates, connection types |
| [Architecture](docs/architecture.md) | Module dependency, data flow, label convention |
| [Development](docs/development.md) | Dev setup, adding services, running tests |
| [Deployment](docs/deployment.md) | Build, Docker, release process |

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

## License

[MIT](LICENSE)
