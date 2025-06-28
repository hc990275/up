#!/bin/bash
set -e

FTP_PORT="21"
PASSIVE_PORTS="60000 65535"
FTP_DIR="/var/www"
PUBLIC_IP=$(curl -s ipv4.ip.sb || curl -s ipinfo.io/ip)

function install_ftp() {
    echo "📥 安装Pure-FTPd..."
    apt update
    apt install -y build-essential wget curl openssl libssl-dev iptables

    cd /usr/local/src
    wget https://github.com/jedisct1/pure-ftpd/releases/download/1.0.51/pure-ftpd-1.0.51.tar.gz
    tar -zxvf pure-ftpd-1.0.51.tar.gz
    cd pure-ftpd-1.0.51
    ./configure --with-everything --with-tls
    make && make install

    echo "🔐 创建SSL证书..."
    mkdir -p /etc/ssl/private
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/ssl/private/pure-ftpd.pem \
        -out /etc/ssl/private/pure-ftpd.pem \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=FTP/OU=PureFTP/CN=${PUBLIC_IP}"
    chmod 600 /etc/ssl/private/pure-ftpd.pem

    echo "📂 创建FTP目录..."
    mkdir -p ${FTP_DIR}
    chmod -R 777 ${FTP_DIR}
    groupadd ftpgroup || true
    useradd -g ftpgroup -d ${FTP_DIR} -s /sbin/nologin ftpuser || true
    chown ftpuser:ftpgroup ${FTP_DIR}

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

    echo "🔥 配置防火墙..."
    iptables -I INPUT -p tcp --dport ${FTP_PORT} -j ACCEPT
    iptables -I INPUT -p tcp --dport 60000:65535 -j ACCEPT
    iptables-save > /etc/iptables.rules

    echo "✅ Pure-FTPd安装完成"
}

function add_user() {
    read -p "请输入FTP用户名: " username
    mkdir -p ${FTP_DIR}/${username}
    pure-pw useradd $username -u ftpuser -g ftpgroup -d ${FTP_DIR}/${username}
    pure-pw mkdb
    echo "✅ 用户 $username 已添加"
}

function delete_user() {
    read -p "请输入要删除的FTP用户名: " username
    pure-pw userdel $username
    pure-pw mkdb
    rm -rf ${FTP_DIR}/${username}
    echo "✅ 用户 $username 已删除"
}

function uninstall_ftp() {
    systemctl stop pure-ftpd
    systemctl disable pure-ftpd
    rm -f /etc/systemd/system/pure-ftpd.service
    rm -rf /usr/local/sbin/pure-ftpd*
    rm -rf /usr/local/src/pure-ftpd*
    rm -rf /etc/ssl/private/pure-ftpd.pem
    rm -rf /etc/pure-ftpd
    userdel ftpuser || true
    groupdel ftpgroup || true
    iptables -D INPUT -p tcp --dport 21 -j ACCEPT
    iptables -D INPUT -p tcp --dport 60000:65535 -j ACCEPT
    iptables-save > /etc/iptables.rules
    echo "✅ Pure-FTPd已卸载"
}

function menu() {
    clear
    echo "=================================="
    echo "🚀 Pure-FTPd 一键管理工具"
    echo "=================================="
    echo "1. 安装 Pure-FTPd"
    echo "2. 启动 Pure-FTPd"
    echo "3. 停止 Pure-FTPd"
    echo "4. 重启 Pure-FTPd"
    echo "5. 查看 Pure-FTPd 状态"
    echo "6. 添加FTP用户"
    echo "7. 删除FTP用户"
    echo "8. 卸载 Pure-FTPd"
    echo "0. 退出"
    echo "=================================="
    read -p "请输入数字选择操作: " num
    case "$num" in
        1)
            install_ftp
            ;;
        2)
            systemctl start pure-ftpd
            ;;
        3)
            systemctl stop pure-ftpd
            ;;
        4)
            systemctl restart pure-ftpd
            ;;
        5)
            systemctl status pure-ftpd
            ;;
        6)
            add_user
            ;;
        7)
            delete_user
            ;;
        8)
            uninstall_ftp
            ;;
        0)
            exit 0
            ;;
        *)
            echo "❌ 无效选项，请重新输入"
            ;;
    esac
}

while true
do
    menu
    read -p "按回车继续..." dummy
done