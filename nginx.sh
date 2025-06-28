#!/bin/bash

# =========================
# 一键Nginx HTTPS部署脚本
# 域名：www.abcai.online
# IP：43.165.68.5
# =========================

set -e

# ----------- 安装必备组件 ----------
echo "🛠️ 安装Nginx和Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx ufw

# ----------- 创建网站目录 ----------
mkdir -p /var/www/html
echo "<h1>abcai.online HTTPS 正常运行</h1>" > /var/www/html/index.html

# ----------- 防火墙设置 ----------
echo "🧱 开放防火墙端口 80 和 443..."
ufw allow 'Nginx Full' || true
ufw allow 80
ufw allow 443

# ----------- 写入Nginx配置 ----------
echo "📜 写入Nginx配置..."
cat > /etc/nginx/sites-available/abcai.conf <<EOF
server {
    listen 80;
    server_name www.abcai.online abcai.online;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name www.abcai.online abcai.online;

    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/abcai.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/abcai.online/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# 启用配置
ln -sf /etc/nginx/sites-available/abcai.conf /etc/nginx/sites-enabled/abcai.conf

# 删除默认站点（可选）
rm -f /etc/nginx/sites-enabled/default

# ----------- 检查并重启Nginx ----------
echo "🔧 测试并重载Nginx..."
nginx -t && systemctl reload nginx

# ----------- 申请SSL证书 ----------
echo "🔑 正在申请SSL证书..."
certbot --nginx -d abcai.online -d www.abcai.online --agree-tos -m your@email.com --no-eff-email --redirect

# ----------- 检查证书自动续期 ----------
echo "🔁 检查证书自动续期..."
certbot renew --dry-run

# ----------- 完成 ----------
echo "✅ HTTPS 网站部署完成！访问：https://www.abcai.online/"