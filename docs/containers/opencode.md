# opencode 配置 & 使用

AI 编程助手，Ubuntu 24.04 定制镜像。详细构建说明见 [docker/opencode/README.md](../../docker/opencode/README.md)。

## 安装

```bash
./install-one.sh opencode
```

## 访问

安装完成后通过域名访问：`https://opencode.<你的域名>`，密码在安装时设置。

## 常用操作

```bash
docker exec -it opencode bash    # 进入容器
docker logs -f opencode          # 查看日志
docker restart opencode          # 重启
```

## 容器内包管理

- `apt install <包名>` — 安装并自动持久化（容器重建后自动恢复）
- `sudo apt update` — 更新源
- 包列表保存在 `~/.config/apt-packages.list`

## 持久化卷

| 路径 | 说明 |
|------|------|
| `<data>/opencode/home` | 用户数据 |
| `<data>/opencode/workspace` | 工作目录 |
| `<data>/opencode/apt-cache` | APT 缓存 |

## SSH 模式

安装时可选两种模式：
- **复用宿主机**: 挂载 `~/.ssh`，直接使用宿主机密钥
- **独立目录**: 自动生成 ed25519 密钥对

## 额外文件夹映射

安装时可添加额外的 `宿主机路径:容器路径` 映射，如 `/mnt/data:/data`。

## 网络模式

支持 bridge（默认）和 macvlan，安装时可选。

## 国内加速

安装时可选：
- APT 阿里云镜像源
- GitHub 下载代理（如 `https://ghproxy.com/`）
