#!/bin/bash
set -e

# 配置
FTP_PORT="21"
PASSIVE_PORTS="60000 65535"
PUBLIC_IP=$(curl -s ipv4.ip.sb || curl -s ipinfo.io/ip)
FTP_DIR="/var/www"

echo "📥 开始安装依赖..."
apt update
apt install -y build-essential wget curl openssl libssl-dev iptables

echo "📦 下载Pure-FTPd源码..."
cd /usr/local/src
wget https://github.com/jedisct1/pure-ftpd/releases/download/1.0.51/pure-ftpd-1.0.51.tar.gz
tar -zxvf pure-ftpd-1.0.51.tar.gz
cd pure-ftpd-1.0.51

echo "🔧 编译并安装..."
./configure --with-everything --with-tls
make
make install

echo "🔐 生成SSL证书..."
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
-keyout /etc/ssl/private/pure-ftpd.pem \
-out /etc/ssl/private/pure-ftpd.pem \
-subj "/C=CN/ST=Beijing/L=Beijing/O=FTP/OU=PureFTP/CN=${PUBLIC_IP}"
chmod 600 /etc/ssl/private/pure-ftpd.pem

echo "📂 创建FTP根目录..."
mkdir -p ${FTP_DIR}
chmod -R 777 ${FTP_DIR}

echo "⚙️ 创建Systemd服务..."
cat > /etc/systemd/system/pure-ftpd.service <<EOF
[Unit]
Description=Pure-FTPd FTP server
After=network.target

[Service]
ExecStart=/usr/local/sbin/pure-ftpd -A -E -R -j -lpuredb:/etc/pure-ftpd/pureftpd.pdb -p ${PASSIVE_PORTS} -P ${PUBLIC_IP} --tls=1
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pure-ftpd
systemctl start pure-ftpd

echo "🔥 配置防火墙端口..."
iptables -I INPUT -p tcp --dport ${FTP_PORT} -j ACCEPT
iptables -I INPUT -p tcp --dport 60000:65535 -j ACCEPT
iptables-save > /etc/iptables.rules

echo "👤 创建匿名用户（可选）"
groupadd ftpgroup || true
useradd -g ftpgroup -d ${FTP_DIR} -s /sbin/nologin ftpuser || true
chown ftpuser:ftpgroup ${FTP_DIR}

echo "✅ 安装完成"
echo "============================"
echo "🌐 地址: ${PUBLIC_IP}"
echo "🚪 端口: ${FTP_PORT}"
echo "📂 目录: ${FTP_DIR}"
echo "🔐 模式: FTP over TLS (强制加密)"
echo "👥 登录方式: 匿名 (ftpuser) 或配置虚拟用户"
echo "============================"