#!/bin/bash

# ==============================
# 🚀 超级防呆Nginx HTTPS一键部署 (修订版)
# 域名：www.abcai.online abcai.online
# 邮箱：haichen505808@gmail.com
# ==============================

# --- 用户配置 ---
DOMAIN="abcai.online"
DOMAIN_WWW="www.abcai.online"
EMAIL="haichen505808@gmail.com" # 确保这是一个有效的邮箱，用于Certbot通知
WEBROOT="/var/www/html"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}.conf"

# --- 脚本逻辑 ---
set -e # 任何命令失败时立即退出

echo "=============================="
echo "🚀 Nginx + HTTPS 自动部署开始"
echo "域名: ${DOMAIN}"
echo "=============================="

## 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 请使用 root 用户运行此脚本。"
    exit 1
fi

## 检查域名解析
echo "🌐 检查域名解析..."
# 获取当前服务器公网IP
CURRENT_IP=$(curl -s ipv4.icanhazip.com)

# 使用 dig 获取域名的IP，并过滤出IPv4地址
# @8.8.8.8 指定使用 Google 的 DNS 服务器，避免本地DNS缓存或配置问题
DOMAIN_IP=$(dig +short "${DOMAIN}" @8.8.8.8 | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -n 1)

if [ -z "${DOMAIN_IP}" ]; then
    echo "❌ 无法解析域名 ${DOMAIN} 的IP地址。请检查DNS设置。"
    exit 1
fi

echo "🌐 当前服务器公网IP: ${CURRENT_IP}"
echo "🌐 域名 ${DOMAIN} 解析IP: ${DOMAIN_IP}"

if [ "${CURRENT_IP}" != "${DOMAIN_IP}" ]; then
    echo "❌ 域名 ${DOMAIN} 没有正确解析到本服务器 (${CURRENT_IP})"
    echo "请检查域名DNS解析。"
    exit 1
else
    echo "✅ 域名解析正确。"
fi

## 安装依赖
echo "🛠️ 安装 Nginx, Certbot, Python3-Certbot-Nginx, Curl 和 UFW..."
apt update -y
apt install -y nginx certbot python3-certbot-nginx curl ufw

## 配置防火墙
if command -v ufw >/dev/null 2>&1; then
    echo "🧱 配置防火墙开放 80 和 443 端口..."
    ufw allow 'Nginx Full' || true # 此规则同时开放 80 和 443 端口
    ufw reload
    ufw enable || true # 启用 UFW (如果尚未启用)
else
    echo "ℹ️ UFW 未安装，跳过防火墙配置。"
fi

## 创建网站根目录
echo "🏗️ 创建网站根目录 ${WEBROOT} 并放置测试页面..."
mkdir -p "${WEBROOT}"
echo "<h1>${DOMAIN} 正在部署中...</h1>" > "${WEBROOT}/index.html"

## 写入临时 HTTP 配置 (用于 Certbot 申请证书)
echo "📜 写入Nginx临时HTTP配置 (用于Certbot申请证书)..."
cat > "${NGINX_CONF}" <<EOF
server {
    listen 80;
    listen [::]:80; # 监听 IPv6 地址
    server_name ${DOMAIN} ${DOMAIN_WWW};

    root ${WEBROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# 创建软链接并移除默认配置
ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 检查并重载 Nginx
echo "🔧 检查并重载 Nginx 配置以应用临时 HTTP 设置..."
nginx -t
systemctl reload nginx

## 申请 SSL 证书
echo "🔑 尝试申请或更新Let’s Encrypt证书..."
# 检查证书是否已存在，如果不存在则申请
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    echo "🔐 申请Let’s Encrypt证书..."
    # --nginx 插件自动配置 Nginx
    # -d 指定域名
    # --agree-tos 同意服务条款
    # -m 指定邮箱
    # --no-eff-email 不发送EFF邮件
    # --redirect 让 Certbot 自动配置 Nginx 将 HTTP 重定向到 HTTPS (我们之后会覆盖，但这是一个好的默认行为)
    # --non-interactive 非交互模式
    certbot --nginx -d "${DOMAIN}" -d "${DOMAIN_WWW}" --agree-tos -m "${EMAIL}" --no-eff-email --redirect --non-interactive
    if [ $? -ne 0 ]; then
        echo "❌ Certbot 证书申请失败。请检查日志：/var/log/letsencrypt/letsencrypt.log"
        exit 1
    fi
else
    echo "✅ SSL证书已存在，跳过申请。"
    # 尝试续订现有证书，确保其有效性
    echo "🔄 尝试续订现有证书..."
    certbot renew --nginx -d "${DOMAIN}" -d "${DOMAIN_WWW}" --post-hook "systemctl reload nginx"
fi

## 写入最终带 HTTPS 的 Nginx 配置
echo "⚙️ 写入最终Nginx配置 (HTTP 跳转到 HTTPS)..."
cat > "${NGINX_CONF}" <<EOF
server {
    listen 443 ssl;
    listen [::]:443 ssl; # 监听 IPv6 地址
    server_name ${DOMAIN} ${DOMAIN_WWW};

    root ${WEBROOT};
    index index.html;

    # SSL 证书路径
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # 增强 SSL 安全性
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3; # 推荐使用更安全的 TLS 版本
    ssl_ciphers "ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20"; # 推荐的密码套件
    ssl_prefer_server_ciphers on;

    # 安全头部
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "no-referrer-when-downgrade";

    location / {
        try_files \$uri \$uri/ =404;
    }
}

server {
    listen 80;
    listen [::]:80; # 监听 IPv6 地址
    server_name ${DOMAIN} ${DOMAIN_WWW};
    return 301 https://\$host\$request_uri; # 将所有 HTTP 请求重定向到 HTTPS
}
EOF

# 检查并重载 Nginx
echo "🔧 检查并重载 Nginx 配置以应用最终的 HTTPS 设置..."
nginx -t
systemctl reload nginx

## 更新最终测试页面
echo "<h1>${DOMAIN} HTTPS 正常运行</h1>" > "${WEBROOT}/index.html"

## 完成
echo "=============================="
echo "✅ HTTPS 部署完成！"
echo "🌐 请访问：https://${DOMAIN}/"
echo "=============================="
