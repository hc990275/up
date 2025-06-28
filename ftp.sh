#!/bin/bash

# 脚本：配置 vsftpd FTP 服务
# 适用于 Ubuntu/Debian 系统
# 域名：abcai.online
# IP：43.165.68.5
# FTP 目录：/var/www/
# FTP 用户：990275，密码：990299
# 支持主动和被动模式

# 设置变量
DOMAIN="abcai.online"
SERVER_IP="43.165.68.5"
FTP_USER="990275"
FTP_PASS="990299"
FTP_DIR="/var/www/"

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 权限运行此脚本：sudo $0"
    exit 1
fi

# 更新软件包列表
echo "更新软件包列表..."
apt update
if [ $? -ne 0 ]; then
    echo "apt update 失败，请检查网络连接或 apt 源"
    exit 1
fi

# 1. 安装 vsftpd
echo "安装 vsftpd..."
apt install -y vsftpd
if [ $? -ne 0 ]; then
    echo "vsftpd 安装失败，请检查网络或 apt 源"
    exit 1
fi

# 启用并启动 vsftpd
systemctl enable vsftpd
systemctl start vsftpd
if [ $? -ne 0 ]; then
    echo "vsftpd 启动失败，请检查 systemctl status vsftpd"
    exit 1
fi
echo "vsftpd 已启动"

# 2. 创建 FTP 用户
echo "创建 FTP 用户 $FTP_USER..."
if id "$FTP_USER" >/dev/null 2>&1; then
    echo "用户 $FTP_USER 已存在，跳过创建"
else
    useradd -m -d $FTP_DIR -s /sbin/nologin $FTP_USER
    if [ $? -ne 0 ]; then
        echo "创建用户 $FTP_USER 失败"
        exit 1
    fi
fi

# 设置用户密码
echo "设置用户 $FTP_USER 的密码..."
echo "$FTP_USER:$FTP_PASS" | chpasswd
if [ $? -ne 0 ]; then
    echo "设置密码失败"
    exit 1
fi

# 设置 /var/www/ 权限
echo "设置 $FTP_DIR 权限..."
chown -R $FTP_USER:$FTP_USER $FTP_DIR
if [ $? -ne 0 ]; then
    echo "chown $FTP_DIR 失败"
    exit 1
fi
chmod -R 755 $FTP_DIR
if [ $? -ne 0 ]; then
    echo "chmod $FTP_DIR 失败"
    exit 1
fi

# 如果 Nginx 存在，确保 www-data 组有访问权限
if getent group www-data > /dev/null; then
    echo "为 Nginx 配置 $FTP_DIR 的组权限..."
    chown -R $FTP_USER:www-data $FTP_DIR
    if [ $? -ne 0 ]; then
        echo "chown 为 www-data 组失败"
        exit 1
    fi
    chmod -R 775 $FTP_DIR
    if [ $? -ne 0 ]; then
        echo "chmod 为 www-data 组失败"
        exit 1
    fi
fi

# 3. 配置 vsftpd 支持主动和被动模式
echo "配置 vsftpd..."
VSFTPD_CONF="/etc/vsftpd.conf"
cp $VSFTPD_CONF ${VSFTPD_CONF}.bak
cat > $VSFTPD_CONF << EOL
# 基本配置
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
xferlog_std_format=YES
chroot_local_user=YES
chroot_list_enable=YES
chroot_list_file=/etc/vsftpd.chroot_list
allow_writeable_chroot=YES

# 主动模式
connect_from_port_20=YES
ftp_data_port=20

# 被动模式
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

# 监听设置
listen=YES
listen_ipv6=NO
EOL
if [ $? -ne 0 ]; then
    echo "写入 $VSFTPD_CONF 失败"
    exit 1
fi

# 创建 chroot 列表
echo "创建 chroot 列表..."
touch /etc/vsftpd.chroot_list
if [ $? -ne 0 ]; then
    echo "创建 /etc/vsftpd.chroot_list 失败"
    exit 1
fi
echo "$FTP_USER" >> /etc/vsftpd.chroot_list
if [ $? -ne 0 ]; then
    echo "写入 /etc/vsftpd.chroot_list 失败"
    exit 1
fi

# 4. 配置防火墙
echo "配置防火墙..."
if ufw status | grep -q "Status: active"; then
    ufw allow 21
    ufw allow 20
    ufw allow 40000:50000/tcp
    ufw status
else
    echo "警告：ufw 未启用，请检查云服务器安全组规则，开放端口 20、21 和 40000-50000"
fi

# 5. 重启 vsftpd
echo "重启 vsftpd..."
systemctl restart vsftpd
if [ $? -ne 0 ]; then
    echo "vsftpd 重启失败，请检查 /var/log/vsftpd.log"
    exit 1
fi

# 6. 测试 FTP 配置
echo "测试 FTP 服务..."
if ss -tuln | grep -q ":21"; then
    echo "FTP 服务正在监听端口 21"
else
    echo "错误：FTP 服务未运行，请检查 vsftpd 状态"
    systemctl status vsftpd
    exit 1
fi

# 7. 输出完成信息
echo "FTP 配置完成！"
echo "使用以下信息连接："
echo "主机：$DOMAIN 或 $SERVER_IP"
echo "用户名：$FTP_USER"
echo "密码：已设置（请妥善保存）"
echo "目录：$FTP_DIR"
echo "主动模式：端口 20 已启用"
echo "被动模式：端口范围 40000-50000 已启用"
echo "请使用 FTP 客户端（如 FileZilla）测试连接"
echo "注意：如果使用云服务器，请在安全组中开放端口 20、21 和 40000-50000"