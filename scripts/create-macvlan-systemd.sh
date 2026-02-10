#!/bin/bash
docker_macvlan_network_name=$1
docker_macvlan_forward_ip=$2
set -e

echo "------ macvlan自动路由 systemd 服务 一键部署 ------"

# 物理网卡过滤（只保留enp、eth、ens、eno等常见真实网卡）
ip link show | grep -E '^[0-9]+: (enp|eth|ens|eno)[a-zA-Z0-9]+' | awk '{print $2}' | sed 's/://g' > /tmp/phys_if_list.txt
if [ ! -s /tmp/phys_if_list.txt ]; then
  # 如果检测到没有上述网卡，则回退为全列表再删除虚拟网卡
  ip link show | grep -E '^[0-9]+: [a-zA-Z0-9]+' | awk '{print $2}' | sed 's/://g' | grep -vE '^(lo|docker|br|veth|tap|bond|wl|vir|vmnet|tun|macvlan|ifb|ip6tnl|gretap|gre|dummy)' > /tmp/phys_if_list.txt
fi

echo "可用的物理网卡列表："
cat /tmp/phys_if_list.txt
if [ $(wc -l < /tmp/phys_if_list.txt) -eq 1 ]; then
  PHYS_IF=$(cat /tmp/phys_if_list.txt | head -n 1)
  echo "检测到只有一个物理网卡：$PHYS_IF，将自动使用它。"
else
  read -p "请输入用于macvlan的物理网卡名称（如：enp6s18）: " PHYS_IF
  PHYS_IF=${PHYS_IF:-$(cat /tmp/phys_if_list.txt | head -n 1)}
fi
rm -f /tmp/phys_if_list.txt

# macvlan接口名
MACVLAN_IF="${docker_macvlan_network_name}_forward"

# macvlan接口IP
HOST_IP_BASE=${docker_macvlan_forward_ip} # 去除掩码部分
read -p "请输入macvlan接口子网掩码 (默认24): " HOST_IP_MASK
HOST_IP_MASK=${HOST_IP_MASK:-24}
HOST_IP="${HOST_IP_BASE}/${HOST_IP_MASK}"

# docker macvlan网络名
DOCKER_NET_NAME="${docker_macvlan_network_name}"

# ===== 主监听脚本处理（支持覆盖询问） =====
MAIN_SCRIPT="/usr/local/sbin/macvlan_forward_event_listener.sh"
need_write_main=1
if [ -f "$MAIN_SCRIPT" ]; then
  echo "$MAIN_SCRIPT 已存在。"
  read -p "是否覆盖并重建（y/N）？" REPLY
  case $REPLY in
    [Yy]* )
    need_write_main=1
    ;;
    * )
    need_write_main=0
    echo "跳过主监听脚本重建。"
    ;;
  esac
fi
# 由于需要兼容sh和bash，脚本中不使用任何bash特有语法，确保在纯sh环境下也能运行
if [ $need_write_main -eq 1 ]; then
  echo "创建/覆盖主脚本 $MAIN_SCRIPT"
  cat > "$MAIN_SCRIPT" <<EOF
#!/bin/bash
set -e
MACVLAN_IF="${MACVLAN_IF}"
PHYS_IF="${PHYS_IF}"
HOST_IP="${HOST_IP}"
DOCKER_NET_NAME="${DOCKER_NET_NAME}"

echo "------ macvlan自动路由事件监听脚本启动 ------"  
echo "[DEBUG] MACVLAN_IF=$MACVLAN_IF"
echo "[DEBUG] PHYS_IF=$PHYS_IF"
echo "[DEBUG] HOST_IP=$HOST_IP"
echo "[DEBUG] DOCKER_NET_NAME=$DOCKER_NET_NAME"
if ip link show "\$MACVLAN_IF" >/dev/null 2>&1; then
  echo "macvlan接口 \$MACVLAN_IF 已存在"
else
  echo "创建macvlan接口: ip link add \$MACVLAN_IF link \$PHYS_IF type macvlan mode bridge"
  ip link add "\$MACVLAN_IF" link "\$PHYS_IF" type macvlan mode bridge
fi

if ip addr show dev "\$MACVLAN_IF" | grep -q "\${HOST_IP%/*}"; then
  echo "macvlan接口 \$MACVLAN_IF 已配置IP \${HOST_IP%/*}"
else
  echo "为 \$MACVLAN_IF 添加IP \$HOST_IP"
  ip addr add "\$HOST_IP" dev "\$MACVLAN_IF"
fi

ip link set "\$MACVLAN_IF" up

sync_routes() {
  # 用awk从docker network inspect获取所有容器的IPv4地址，并去除掩码部分
  CONTAINER_IPS_WITH_MASK=\$(docker network inspect "\$DOCKER_NET_NAME" -f '{{range .Containers}}{{.IPv4Address}} {{end}}') 
  CONTAINER_IPS=""
  for ip in \$CONTAINER_IPS_WITH_MASK; do
    CONTAINER_IPS="\$CONTAINER_IPS \${ip%%/*}"
  done
  ROUTE_IPS=\$(ip route | grep "dev \$MACVLAN_IF" | awk '{print \$1}')
  for ip in \$CONTAINER_IPS; do
    if echo "\$ROUTE_IPS" | grep -qx "\$ip"; then
      echo "路由 \$ip 已存在，跳过"
    else
      echo "添加路由 \$ip 到 \$MACVLAN_IF"
      ip route add "\$ip" dev "\$MACVLAN_IF"
    fi
  done
  for ip in \$ROUTE_IPS; do
    # 只删除形式为纯IP（没有/的），不删除类似192.168.6.0/24网段路由
    if [[ "\$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\$ ]] && ! echo "\$CONTAINER_IPS" | grep -qx "\$ip"; then
      echo "删除已失效路由 \$ip from \$MACVLAN_IF"
      ip route del "\$ip" dev "\$MACVLAN_IF" || true
    fi
  done
}

echo "启动时同步所有容器的路由..."
sync_routes

docker events --filter event=start --filter event=connect --filter event=disconnect --filter event=die --filter event=destroy --filter network="\$DOCKER_NET_NAME" | \\
while read -r event; do
  echo "检测到docker网络事件，重新同步所有路由..."
  sync_routes
done
EOF
  chmod +x "$MAIN_SCRIPT"
fi

# ===== 生成 systemd unit（支持覆盖询问） =====
SYSTEMD_UNIT="/etc/systemd/system/macvlan_forward_event_listener.service"
need_write_unit=1
if [ -f "$SYSTEMD_UNIT" ]; then
  echo "$SYSTEMD_UNIT 已存在。"
  read -p "是否覆盖并重建（y/N）？" REPLY
  case $REPLY in
    [Yy]* )
    need_write_unit=1
    ;;
    * )
    need_write_unit=0
    echo "跳过systemd unit重建。"
    ;;
  esac
fi
if [ $need_write_unit -eq 1 ]; then
  echo "创建/覆盖systemd unit $SYSTEMD_UNIT"
  cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=macvlan forward: docker events route patcher
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Environment="MACVLAN_IF=${MACVLAN_IF}"
Environment="PHYS_IF=${PHYS_IF}"
Environment="HOST_IP=${HOST_IP}"
Environment="DOCKER_NET_NAME=${DOCKER_NET_NAME}"
ExecStart=${MAIN_SCRIPT}
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable --now macvlan_forward_event_listener.service
systemctl restart macvlan_forward_event_listener.service
echo "服务启动完毕，当前状态："
systemctl status macvlan_forward_event_listener.service --no-pager
echo "如需日志实时查看：journalctl -u macvlan_forward_event_listener.service -f"