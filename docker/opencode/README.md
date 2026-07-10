# opencode 自定义 Docker 镜像

基于 Ubuntu 24.04 的 opencode 运行环境，集成 apt 包持久化、健康检查、国内加速支持。

## 速览

| 项目 | 内容 |
|------|------|
| 基础镜像 | `ubuntu:24.04` |
| opencode 安装 | GitHub Releases 直接下载 + 版本自动检测 |
| 包管理 | `apt` 安装自动持久化（wrapper 机制） |
| 预装工具 | git, python3, nodejs, build-essential, ripgrep, fzf, jq… |
| 用户 | `opencode` (NOPASSWD sudo) |
| 健康检查 | 180s 启动宽容期 + curl 端口检测 |
| 国内加速 | APT 阿里云镜像 + ghproxy 代理下载 |
| 镜像仓库 | `ghcr.io/dezhishen/opencode-custom` |

> ⚠️ **UID 注意**：预构建镜像预设 `UID=1000`。若宿主机用户 UID 不为 1000，安装脚本会自动回退本地构建。若强制使用 ghcr 镜像，sudo/apt 功能将不可用（opencode 服务仍正常）。详见[UID 兼容性](#uid-兼容性)。

## 快速使用

### 从 ghcr.io 拉取

```bash
docker pull ghcr.io/dezhishen/opencode-custom:latest
```

### 或本地构建

```bash
docker build \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  -t opencode-custom:latest \
  docker/opencode
```

## 构建参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `UID` | `1000` | 容器内 opencode 用户 UID，应与宿主机一致 |
| `GID` | `1000` | 容器内 opencode 用户 GID |
| `OPENCODE_VERSION` | `latest` | opencode 版本号（如 `v1.2.3`），`latest` 时自动检测 |
| `APT_MIRROR` | `""` | APT 镜像源，设为 `aliyun` 使用阿里云镜像 |
| `OPENCODE_DOWNLOAD_PROXY` | `""` | GitHub Release 下载代理，如 `https://ghproxy.com/` |

### 国内构建示例

```bash
docker build \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  --build-arg APT_MIRROR=aliyun \
  --build-arg OPENCODE_DOWNLOAD_PROXY=https://ghproxy.com/ \
  -t opencode-custom:latest \
  docker/opencode
```

## UID 兼容性

### 问题

预构建镜像（ghcr.io）的 opencode 用户预设 `UID=1000`，而 `sudo` 基于用户名鉴权：

```
/etc/sudoers.d/opencode  →  opencode ALL=(ALL) NOPASSWD:ALL
/etc/passwd               →  opencode:x:1000:1000

docker run --user 1002  → UID 不匹配 → whoami 解析失败 → sudo 拒绝
```

### 影响

| 功能 | UID=1000 (匹配) | UID≠1000 (不匹配) |
|------|:---:|:---:|
| opencode 服务 | ✅ | ✅ |
| `apt install` 持久化 | ✅ | ❌ |
| `sudo` 操作 | ✅ | ❌ |
| 文件读写 | ✅ | ✅ |

### 处理策略

| 场景 | 行为 |
|------|------|
| `install-opencode.sh` 检测到 UID≠1000 | 自动回退**本地构建**（传正确 UID） |
| 强制使用 ghcr 镜像 (UID≠1000) | ⚠️ 跳过 apt/sudo，opencode 仍可启动 |
| `OPENCODE_BUILD_LOCAL=true` | 强制本地构建 |

## 特性

### apt 包持久化

容器内使用 `apt install <包名>` 安装的包会自动记录到 `~/.config/apt-packages.list`。容器重建时，entrypoint 自动恢复所有已记录的包。

```bash
# 容器内安装
docker exec -it opencode bash
apt install vim htop net-tools

# 重建容器后自动恢复 — 无需手动重装
```

### 预装开发工具

`git` `git-lfs` `build-essential` `python3` `nodejs` `npm` `ripgrep` `fzf` `jq` `fd-find`

### 健康检查

- `start-period=180s`：3 分钟启动宽容期，覆盖 apt 包恢复时间
- 初始化阶段（无就绪标记）始终返回健康，不会因启动慢被误杀
- 就绪后通过 `curl` 检测 opencode 服务端口

### sudo 支持

opencode 用户拥有 NOPASSWD sudo，可执行 `sudo apt update` 等操作。

### snap/遥测清理

移除 snapd、ubuntu-advantage、motd-news、apport、whoopsie 等组件。

## 运行时环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OPENCODE_PORT` | `4096` | opencode 服务端口 |
| `OPENCODE_SERVER_PASSWORD` | — | 访问密码 |
| `OPENCODE_APT_MIRROR` | `default` | 运行时 APT 镜像源，`aliyun` 切阿里云 |
| `OPENCODE_BUILD_LOCAL` | `false` | 强制本地构建（不从 ghcr 拉取） |

## 卷挂载

| 宿主机路径 | 容器路径 | 说明 |
|-----------|---------|------|
| `./home` | `/home/opencode` | 用户数据（dotfiles、配置、apt 包列表） |
| `./workspace` | `/workspace` | 默认工作目录 |
| `./apt-cache` | `/var/cache/apt` | APT 缓存（加速包重装） |
| `./config` | `/home/opencode/.config/opencode` | opencode 配置 |

## 文件说明

| 文件 | 用途 |
|------|------|
| `Dockerfile` | 镜像构建定义 |
| `entrypoint.sh` | 容器入口，apt 包恢复 + bashrc 初始化 + opencode 启动 |
| `healthcheck.sh` | 健康检查脚本 |
| `apt-get.wrapper` | apt-get 透明拦截器，记录安装到持久化列表 |
| `apt.wrapper` | apt 透明拦截器 |

## CI/CD

GitHub Actions 自动构建推送到 `ghcr.io/dezhishen/opencode-custom`。

- **触发条件**：`docker/opencode/**` 变更、每周定时、手动触发
- **去重**：同一 opencode 版本仅构建一次
- **标签**：`latest`、`opencode-v1.2.3`、commit SHA、日期

详见 `.github/workflows/build-opencode.yml`。
