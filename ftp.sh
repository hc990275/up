#!/bin/bash
set -e

# 安装依赖
apt update
apt install -y openssl

# 下载pure-ftpd最新二进制
cd /usr/sbin/
wget https://download.pureftpd.org/pub/pure-ftpd/releases/pure-ftpd-1.0.49.tar.gz
tar -xzf pure-ftpd-1.0.49.tar.gz
cd pure-ftpd-1.0.49
./configure --with-everything --prefix=/usr --with-tls
make
make install

# 创建FTP目录
mkdir -p /var/www
chmod -R 777 /var/www

# 创建SSL证书
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
-keyout /etc/ssl/private/pure-ftpd.pem \
-out /etc/ssl/private/pure-ftpd.pem \
-subj "/C=CN/ST=Beijing/L=Beijing/O=hyabcai/OU=FTP/CN=hy.abcai.online"
chmod 600 /etc/ssl/private/pure-ftpd.pem

# 创建systemd服务
cat >/etc/systemd/system/pure-ftpd.service <<EOF
[Unit]
Description=Pure-FTPd server
After=network.target

[Service]
ExecStart=/usr/sbin/pure-ftpd -A -E -R -H -j -J -lpuredb:/etc/pureftpd.pdb -O clf:/var/log/pureftpd.log -p 60000:65535 -P $(curl -s ifconfig.me) --tls=2 --anonroot=/var/www --noanonymousupload

[Install]
WantedBy=multi-user.target
EOF

# 防火墙
ufw allow 21/tcp
ufw allow 60000:65535/tcp
ufw reload

# 启动服务
systemctl daemon-reload
systemctl enable pure-ftpd
systemctl restart pure-ftpd

echo "============================"
echo "✅ FTP部署完成"
echo "🌐 地址: $(curl -s ifconfig.me) 或 hy.abcai.online"
echo "🚪 端口: 21"
echo "📂 目录: /var/www"
echo "🔐 模式: FTP over TLS (强制加密)"
echo "👥 登录方式: 匿名 (anonymous)"
echo "============================"