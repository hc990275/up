#!/bin/bash

# ========= 基础配置 =========
DOMAIN="abcai.online"             # 你的域名
TUNNEL_NAME="abcai"               # Tunnel名称，自定义
LOCAL_SERVICE="http://localhost:8080"  # 本地服务地址
# =============================

set -e

echo "=== 🚀 Cloudflare Tunnel 自动部署开始 ==="

# ==== 检查并安装 cloudflared ====
if ! command -v cloudflared &> /dev/null; then
    echo ">>> ⬇️ 正在安装 cloudflared..."
    wget -O cloudflared-linux-amd64.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb || (apt-get update && apt-get install -f -y)
    rm -f cloudflared-linux-amd64.deb
fi

# ==== 登录 Cloudflare ====
echo ">>> 🌐 请在浏览器中登录Cloudflare授权..."
cloudflared tunnel login

# ==== 创建 Tunnel ====
if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
    echo ">>> 🔍 Tunnel [$TUNNEL_NAME] 已存在，跳过创建。"
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
else
    echo ">>> 🔧 正在创建 Tunnel：$TUNNEL_NAME"
    cloudflared tunnel create "$TUNNEL_NAME"
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
fi

echo ">>> 🆔 Tunnel ID: $TUNNEL_ID"

# ==== 创建配置文件 ====
mkdir -p /etc/cloudflared

cat > /etc/cloudflared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $DOMAIN
    service: $LOCAL_SERVICE
  - service: http_status:404
EOF

# ==== 绑定域名到 Tunnel ====
echo ">>> 🔗 正在将域名 $DOMAIN 绑定到 Tunnel..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN"

# ==== 写入 systemd 后台服务 ====
cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel Service
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ==== 启动服务 ====
echo ">>> 🚀 正在启动 cloudflared 服务..."
systemctl daemon-reload
systemctl enable cloudflared
systemctl restart cloudflared

echo "======================================="
echo "✅ Cloudflare Tunnel 部署完成！"
echo "✅ 公网地址：https://$DOMAIN"
echo "✅ Tunnel后台运行，断线自动重连"
echo "======================================="