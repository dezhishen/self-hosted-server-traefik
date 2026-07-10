# 网络 & 配置教程

## 网络模式

| 模式 | 创建命令 | 说明 |
|------|---------|------|
| bridge | `scripts/create-docker-bridge-network.sh` | 默认，容器名互通 |
| macvlan | `scripts/create-docker-macvlan-network.sh` | 独立 IP，自动分配 + Traefik provider |
| internal | `scripts/create-docker-internal-network.sh` | 安全隔离，阻隔外网 |

## 容器互通

| 方向 | 方式 |
|------|------|
| bridge ⇄ bridge | `http://容器名:端口` |
| bridge → host | `http://网关IP:端口` |
| host → bridge | 通过域名（经 Traefik） |

### 获取网关

```bash
docker network inspect traefik --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}'
```

## 外网访问

- **Cloudflare Tunnel**: `docker run cloudflare/cloudflared tunnel ...`
- **frp / ngrok**: 轻量内网穿透
- **Tailscale**: 异地组网

## 配置系统

参数存于 `~/.args/`，每个参数一个文件：

```
~/.args/
├── domain              # 域名
├── base_data_dir       # 数据根目录
└── tls                 # SSL 开关
```

安装脚本自动读写，git pull 不覆盖。
