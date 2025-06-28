#!/bin/bash
# Pure-FTPd 匿名FTP搭建（目录/var/www），支持TLS加密

# ================= 配置 =================
FTP_DIR="/var/www"               # 匿名FTP根目录
SERVER_IP="43.165.68.5"          # 公网IP（请修改为你的IP）

# ========================================

echo "▶️ 安装Pure-FTPd..."
apt update -y && apt install -y pure-ftpd openssl

echo "▶️ 配置FTP目录权限..."
mkdir -p "$FTP_DIR"
chown -R nobody:nogroup "$FTP_DIR"
chmod -R 755 "$FTP_DIR"

echo "▶️ 创建SSL证书..."
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
-keyout /etc/ssl/private/pure-ftpd.pem \
-out /etc/ssl/private/pure-ftpd.pem \
-subj "/C=CN/ST=Beijing/L=Beijing/O=hyabcai/OU=FTP/CN=$SERVER_IP"

chmod 600 /etc/ssl/private/pure-ftpd.pem

echo "▶️ 创建 systemd 服务..."
cat >/etc/systemd/system/pure-ftpd.service <<EOF
[Unit]
Description=Pure-FTPd FTP server (Anonymous)
After=network.target

[Service]
ExecStart=/usr/sbin/pure-ftpd \
-A -E -R \
-P $SERVER_IP -p 60000:65535 \
-c 50 -C 5 -l anonymous \
--tls=2
ExecStop=/usr/bin/killall pure-ftpd
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "▶️ 配置防火墙..."
ufw allow 21/tcp
ufw allow 60000:65535/tcp
ufw reload

echo "▶️ 启动FTP服务..."
systemctl daemon-reload
systemctl enable pure-ftpd
systemctl restart pure-ftpd

echo "✅ 匿名FTP已安装并运行"
echo "============================"
echo "🌐 地址: $SERVER_IP 或 你的域名"
echo "🚪 端口: 21"
echo "📂 目录: $FTP_DIR"
echo "🔐 模式: FTP over TLS (强制加密)"
echo "👥 登录方式: 匿名，无需账号密码"
echo "============================"