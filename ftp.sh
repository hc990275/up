#!/bin/bash
# Pure-FTPd 一键安装脚本（修正版）
# 支持 Ubuntu 18/20/22
# 作者: hc990275

FTP_PORT=21
PASV_MIN_PORT=60000
PASV_MAX_PORT=65535
FTP_DIR="/var/www"
SSL_CERT="/etc/ssl/private/pure-ftpd.pem"

echo "▶️ 开始安装 Pure-FTPd..."

# 获取公网 IP
PUBLIC_IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me || curl -s ipinfo.io/ip)

# 安装软件
apt update
apt install -y pure-ftpd openssl iptables-persistent

# 配置FTP目录
mkdir -p "$FTP_DIR"
chmod -R 777 "$FTP_DIR"

# 配置被动端口
echo "$PASV_MIN_PORT $PASV_MAX_PORT" > /etc/pure-ftpd/conf/PassivePortRange

# 配置公网IP
echo "$PUBLIC_IP" > /etc/pure-ftpd/conf/ForcePassiveIP

# 配置TLS
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout $SSL_CERT -out $SSL_CERT \
    -subj "/C=CN/ST=Internet/L=Internet/O=FTPServer/OU=Org/CN=$PUBLIC_IP"
chmod 600 $SSL_CERT
echo "2" > /etc/pure-ftpd/conf/TLS

# 启用匿名只读
echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
echo "no" > /etc/pure-ftpd/conf/AnonymousCanUpload

# 启动并设置自启
systemctl restart pure-ftpd
systemctl enable pure-ftpd

# 防火墙放行
iptables -I INPUT -p tcp --dport $FTP_PORT -j ACCEPT
iptables -I INPUT -p tcp --dport $PASV_MIN_PORT:$PASV_MAX_PORT -j ACCEPT
iptables-save > /etc/iptables/rules.v4

echo ""
echo "============================"
echo "✅ Pure-FTPd 安装完成"
echo "🌐 地址: $PUBLIC_IP"
echo "🚪 端口: $FTP_PORT"
echo "📂 目录: $FTP_DIR"
echo "🔐 模式: FTP over TLS (强制加密)"
echo "👤 登录: 匿名，无需账号"
echo "============================"