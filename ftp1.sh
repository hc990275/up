#!/bin/bash

# 定义变量
USER="Aa990275"
VSFTPD_CONF="/etc/vsftpd.conf"
USERLIST_FILE="/etc/vsftpd.userlist"
FTPUSERS_FILE="/etc/ftpusers"
WWW_DIR="/var/www/"

# 检查是否以 root 身份运行
if [ "$(id -u)" != "0" ]; then
    echo "错误：请以 root 身份运行此脚本！"
    exit 1
fi

# 1. 检查并修改 vsFTPd 配置文件
echo "正在检查和配置 vsFTPd..."
if [ -f "$VSFTPD_CONF" ]; then
    # 确保 local_enable=YES 和 write_enable=YES
    sed -i 's/^#*local_enable=.*/local_enable=YES/' "$VSFTPD_CONF"
    sed -i 's/^#*write_enable=.*/write_enable=YES/' "$VSFTPD_CONF"

    # 如果 userlist_enable=YES，确保 userlist_deny=NO
    if grep -q "^userlist_enable=YES" "$VSFTPD_CONF"; then
        sed -i 's/^#*userlist_deny=.*/userlist_deny=NO/' "$VSFTPD_CONF"
        # 确保用户 Aa990275 在 userlist 中
        if ! grep -Fx "$USER" "$USERLIST_FILE" > /dev/null; then
            echo "$USER" >> "$USERLIST_FILE"
            echo "已将 $USER 添加到 $USERLIST_FILE"
        fi
    fi
    echo "vsFTPd 配置文件已更新"
else
    echo "错误：未找到 $VSFTPD_CONF"
    exit 1
fi

# 2. 检查 /etc/ftpusers，确保 Aa990275 不在其中
if [ -f "$FTPUSERS_FILE" ]; then
    if grep -Fx "$USER" "$FTPUSERS_FILE" > /dev/null; then
        sed -i "/^$USER$/d" "$FTPUSERS_FILE"
        echo "已从 $FTPUSERS_FILE 中移除 $USER"
    else
        echo "$USER 不在 $FTPUSERS_FILE 中，无需修改"
    fi
else
    echo "警告：未找到 $FTPUSERS_FILE，跳过检查"
fi

# 3. 重启 vsFTPd 服务
echo "正在重启 vsFTPd 服务..."
systemctl restart vsftpd
if systemctl is-active --quiet vsftpd; then
    echo "vsFTPd 服务已成功重启"
else
    echo "错误：vsFTPd 服务重启失败，请检查 systemctl status vsftpd"
    exit 1
fi

# 4. 检查防火墙并开放 FTP 端口
echo "检查防火墙设置..."
if command -v ufw >/dev/null; then
    if ufw status | grep -q "21/tcp"; then
        echo "FTP 端口（21）已在防火墙中开放"
    else
        ufw allow 21/tcp
        echo "已开放 FTP 端口（21）"
    fi
else
    echo "警告：未检测到 ufw，跳过防火墙检查"
fi

# 5. 验证 /var/www/ 目录权限
echo "正在验证 $WWW_DIR 权限..."
if [ -d "$WWW_DIR" ]; then
    chown -R "$USER:www-data" "$WWW_DIR"
    chmod -R 775 "$WWW_DIR"
    ls -ld "$WWW_DIR"
    echo "$WWW_DIR 权限已设置为 $USER:www-data，模式 775"
else
    echo "错误：$WWW_DIR 目录不存在"
    exit 1
fi

# 6. 输出日志提示
echo "脚本执行完成！请尝试使用以下命令测试 FTP 登录："
echo "ftp localhost"
echo "用户名: $USER"
echo "密码: Aa990299"
echo "如果仍无法登录，请检查日志："
echo "tail -f /var/log/vsftpd.log"
echo "或：journalctl -u vsftpd"