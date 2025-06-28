#!/bin/bash

# ==============================
# 🚀 超级防呆Nginx HTTPS一键部署
# 域名：www.abcai.online abcai.online
# 公网IP：43.165.68.5
# 邮箱：haichen505808@gmail.com
# ==============================

DOMAIN="abcai.online"
DOMAIN_WWW="www.abcai.online"
EMAIL="haichen505808@gmail"
WEBROOT="/var/www/html"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}.conf"

set -e

echo "=============================="
echo "🚀 Nginx + HTTPS 自动部署开始"
echo "域名: ${DOMAIN}"
echo "=============================="

# -------------------------------
# 🧠 检查是否有sudo权限
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 请使用 root 用户运行此脚本。"
    exit 1
fi

# -------------------------------
# 🧠 检查域名是否解析正确
CURRENT_IP=$(curl -s ipv4.icanhazip.com)
DOMAIN_IP=$(ping -c 1 ${DOMAIN} | grep "PING" | awk -F'(' '{print $2}' | awk -F')' '{print $1}')

echo "🌐 当前服务器公网IP: ${CURRENT_IP}"
echo "🌐 域名 ${DOMAIN} 解析IP: ${DOMAIN_IP}"

if [ "${CURRENT_IP}" != "${DOMAIN_IP}" ]; then
    echo "❌ 域名 ${DOMAIN} 没有正确解析到本服务器 (${CURRENT_IP})"
    echo "请检查域名DNS解析。"
    exit 1
else
    echo "✅ 域名解析正确。"
fi

# -------------------------------
# 🔧 安装依赖
echo "🛠️ 安装 Nginx 和 Certbot ..."
apt update
apt install -y nginx certbot python3-certbot-nginx curl ufw

# -------------------------------
# 🔥 开放防火墙
if command -v ufw >/dev/null 2>&1; then
    echo "🧱 配置防火墙开放 80 和 443 ..."
    ufw allow 'Nginx Full' || true
    ufw allow 80
    ufw allow 443
fi

# -------------------------------
# 🏗️ 创建网站根目录
mkdir -p ${WEBROOT}
echo "<h1>${DOMAIN} HTTPS 正常运行</h1>" > ${WEBROOT}/index.html

# -------------------------------
# 📝 写入 HTTP 配置（申请证书用）
echo "📜 写入Nginx临时HTTP配置..."
cat > ${NGINX_CONF} <<EOF
server {
    listen 80;
    server_name ${DOMAIN} ${DOMAIN_WWW};

    root ${WEBROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf ${NGINX_CONF} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 检查并重启 Nginx
nginx -t
systemctl restart nginx

# -------------------------------
# 🔑 申请SSL证书
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo "🔐 申请Let’s Encrypt证书..."
    certbot --nginx -d ${DOMAIN} -d ${DOMAIN_WWW} --agree-tos -m ${EMAIL} --no-eff-email --redirect
else
    echo "✅ SSL证书已存在，跳过申请。"
fi

# -------------------------------
# 🚀 写入最终带HTTPS的配置
echo "⚙️ 写入最终Nginx配置（HTTP跳转到HTTPS）..."
cat > ${NGINX_CONF} <<EOF
server {
    listen 443 ssl;
    server_name ${DOMAIN} ${DOMAIN_WWW};

    root ${WEBROOT};
    index index.html;

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        try_files \$uri \$uri/ =404;
    }
}

server {
    listen 80;
    server_name ${DOMAIN} ${DOMAIN_WWW};
    return 301 https://\$host\$request_uri;
}
EOF

# 检查并重启 Nginx
nginx -t
systemctl restart nginx

# -------------------------------
# 🔄 测试证书续期
echo "🔁 测试证书自动续期..."
certbot renew --dry-run

# -------------------------------
# 🎉 完成
echo "=============================="
echo "✅ HTTPS 部署完成！"
echo "🌐 请访问：https://${DOMAIN}/"
echo "=============================="