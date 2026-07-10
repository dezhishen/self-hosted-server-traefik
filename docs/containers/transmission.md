# transmission 配置

> 一般使用 transmission 做为 iyuu 的辅种器，qbittorrent 做为主种子器

| 设置名 | 配置项 | 说明 |
|--------|--------|------|
| Torrents/Downloading/Download to | `/data/downloads` | 务必设置在 `/data/` 下 |
| Torrents/Downloading/Use temporary directory | `/incomplete-torrents` | 未完成种子目录 |
| Peers/Options/Encryption | Require encryption | 强制加密 |
| Network/Use port forwarding | `true` | UPnP/NAT-PMP |
| Network/Options/Enable uTP | `true` | 减少 ISP 限速 |
