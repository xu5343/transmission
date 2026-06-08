#!/bin/bash
# 一键编译安装 Transmission 4.0.5 服务
# 适用于 Debian 11 / 12

set -e

###########################################
# 配置参数
###########################################
TRANSMISSION_VERSION="4.0.5"
username="admin"
passwd=$(date +%s | md5sum | head -c 8)
rpcport=9091
peerport=51413
downloads="/var/transmission/downloads"  # 默认下载目录

# 安装路径
INSTALL_PREFIX="/usr/local"
BIN_DIR="${INSTALL_PREFIX}/bin"
WEB_DIR="${INSTALL_PREFIX}/share/transmission/web"
CONFIG_DIR="/etc/transmission-daemon"
SERVICE_USER="debian-transmission"

###########################################
# 定义文字颜色
###########################################
Green="\033[32m"
Red="\033[31m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
Yellow="\033[0;33m"
SkyBlue="\033[0;36m"
BlueBG="\033[44;37m"

###########################################
# 函数定义
###########################################
print_info() {
    echo -e "${Green}[INFO]${Font} $1"
}

print_error() {
    echo -e "${Red}[ERROR]${Font} $1"
}

print_success() {
    echo -e "${GreenBG}[SUCCESS]${Font} $1"
}

print_warning() {
    echo -e "${Yellow}[WARNING]${Font} $1"
}

# 错误处理函数
error_exit() {
    print_error "$1"
    exit 1
}

###########################################
# 开始安装
###########################################
clear
echo -e "${GreenBG}================================================${Font}"
echo -e "${GreenBG}   一键编译安装 Transmission 4.0.5 服务   ${Font}"
echo -e "${GreenBG}================================================${Font}\n"

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   error_exit "此脚本必须以 root 用户运行"
fi

# 检查系统版本
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    error_exit "无法检测系统版本"
fi

if [[ "$OS" != "debian" ]] || [[ ! "$VER" =~ ^(11|12)$ ]]; then
    print_warning "此脚本专为 Debian 11/12 设计，当前系统: $OS $VER"
    read -p "是否继续安装？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

###########################################
# 用户配置设置
###########################################
echo -e "${BlueBG}   基本配置   ${Font}\n"

# 1. 密码设置
echo -e "${SkyBlue}:: 随机生成密码: ${RedBG} ${passwd} ${Font}"
read -p ":: 请输入自定义密码(按回车使用随机密码): " new_passwd

if [[ ! -z "${new_passwd}" ]]; then
    passwd="${new_passwd}"
    echo -e "${SkyBlue}:: 修改后密码: ${GreenBG} ${passwd} ${Font}\n"
else
    echo ""
fi

# 2. 下载目录设置
echo -e "${SkyBlue}:: 默认下载目录: ${GreenBG} ${downloads} ${Font}"
read -p ":: 请输入自定义下载目录(按回车使用默认): " new_downloads

if [[ ! -z "${new_downloads}" ]]; then
    # 移除末尾的斜杠
    new_downloads="${new_downloads%/}"
    
    # 验证路径有效性（以/开头，只包含合法字符）
    if [[ "${new_downloads}" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
        downloads="${new_downloads}"
        echo -e "${SkyBlue}:: 自定义下载目录: ${GreenBG} ${downloads} ${Font}\n"
    else
        print_warning "路径格式无效，使用默认目录: ${downloads}\n"
    fi
else
    echo ""
fi

# 3. RPC 端口设置
echo -e "${SkyBlue}:: 默认 Web 端口: ${GreenBG} ${rpcport} ${Font}"
read -p ":: 请输入自定义端口(按回车使用默认): " new_rpcport

if [[ ! -z "${new_rpcport}" ]]; then
    # 验证端口号
    if [[ "${new_rpcport}" =~ ^[0-9]+$ ]] && [ "${new_rpcport}" -ge 1024 ] && [ "${new_rpcport}" -le 65535 ]; then
        rpcport="${new_rpcport}"
        echo -e "${SkyBlue}:: 自定义端口: ${GreenBG} ${rpcport} ${Font}\n"
    else
        print_warning "端口号无效(范围:1024-65535)，使用默认端口: ${rpcport}\n"
    fi
else
    echo ""
fi

# 显示配置摘要
echo -e "${BlueBG}   配置摘要   ${Font}"
echo -e "  用户名:     ${Green}${username}${Font}"
echo -e "  密码:       ${Green}${passwd}${Font}"
echo -e "  Web 端口:   ${Green}${rpcport}${Font}"
echo -e "  Peer 端口:  ${Green}${peerport}${Font}"
echo -e "  下载目录:   ${Green}${downloads}${Font}"
echo -e ""
read -p "确认以上配置开始安装？(y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "安装已取消"
    exit 0
fi

###########################################
# 检查端口占用
###########################################
print_info "检查端口占用..."
if netstat -tuln 2>/dev/null | grep -q ":${rpcport} " || ss -tuln 2>/dev/null | grep -q ":${rpcport} "; then
    error_exit "端口 ${rpcport} 已被占用，请更换端口或关闭占用程序"
fi

###########################################
# 安装依赖
###########################################
print_info "正在更新系统并安装编译依赖..."
export DEBIAN_FRONTEND=noninteractive

apt update -y || error_exit "apt update 失败"
apt install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    libevent-dev \
    zlib1g-dev \
    libminiupnpc-dev \
    libnatpmp-dev \
    libsystemd-dev \
    curl \
    wget \
    ca-certificates \
    pkg-config \
    unzip \
    net-tools || error_exit "依赖安装失败"

###########################################
# 下载并编译 Transmission
###########################################
print_info "正在下载 Transmission ${TRANSMISSION_VERSION} 源码..."
cd /tmp
rm -rf transmission-${TRANSMISSION_VERSION}*

# 下载源码，支持重试
for i in {1..3}; do
    if wget -q --show-progress https://github.com/transmission/transmission/releases/download/${TRANSMISSION_VERSION}/transmission-${TRANSMISSION_VERSION}.tar.xz; then
        break
    fi
    if [ $i -eq 3 ]; then
        error_exit "下载 Transmission 源码失败"
    fi
    print_warning "下载失败，重试中... ($i/3)"
    sleep 2
done

tar -xf transmission-${TRANSMISSION_VERSION}.tar.xz || error_exit "解压失败"
cd transmission-${TRANSMISSION_VERSION}

print_info "正在编译 Transmission (可能需要几分钟)..."
mkdir -p build
cd build

cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} .. || error_exit "CMake 配置失败"
make -j$(nproc) || error_exit "编译失败"

print_info "正在安装 Transmission..."
make install || error_exit "安装失败"

# 验证安装
if [ ! -f "${BIN_DIR}/transmission-daemon" ]; then
    error_exit "Transmission 可执行文件未找到"
fi

print_success "Transmission 编译安装成功"

###########################################
# 创建系统用户
###########################################
if ! id -u ${SERVICE_USER} >/dev/null 2>&1; then
    print_info "创建系统用户 ${SERVICE_USER}..."
    useradd --system --home-dir /var/lib/transmission-daemon --create-home --shell /usr/sbin/nologin ${SERVICE_USER}
fi

###########################################
# 创建配置目录和下载目录
###########################################
print_info "创建配置和下载目录..."
mkdir -p ${CONFIG_DIR}
mkdir -p ${downloads}
mkdir -p ${downloads}/incomplete

# 设置目录权限
chown -R ${SERVICE_USER}:${SERVICE_USER} ${downloads}
chown -R ${SERVICE_USER}:${SERVICE_USER} /var/lib/transmission-daemon
chmod -R 755 ${downloads}

print_success "目录创建成功"

###########################################
# 生成配置文件
###########################################
print_info "生成配置文件..."
cat > ${CONFIG_DIR}/settings.json <<EOF
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 540,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1020,
    "alt-speed-up": 50,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "blocklist-url": "http://www.example.com/blocklist",
    "cache-size-mb": 4,
    "dht-enabled": false,
    "download-dir": "${downloads}",
    "download-queue-enabled": true,
    "download-queue-size": 50,
    "encryption": 1,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "${downloads}/incomplete",
    "incomplete-dir-enabled": true,
    "lpd-enabled": false,
    "message-level": 1,
    "peer-congestion-algorithm": "",
    "peer-id-ttl-hours": 6,
    "peer-limit-global": 960,
    "peer-limit-per-torrent": 120,
    "peer-port": ${peerport},
    "peer-port-random-high": 65535,
    "peer-port-random-low": 49152,
    "peer-port-random-on-start": false,
    "peer-socket-tos": "default",
    "pex-enabled": false,
    "port-forwarding-enabled": true,
    "preallocation": 1,
    "prefetch-enabled": true,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2,
    "ratio-limit-enabled": false,
    "rename-partial-files": true,
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-host-whitelist": "",
    "rpc-host-whitelist-enabled": false,
    "rpc-password": "${passwd}",
    "rpc-port": ${rpcport},
    "rpc-url": "/transmission/",
    "rpc-username": "${username}",
    "rpc-whitelist": "",
    "rpc-whitelist-enabled": false,
    "scrape-paused-torrents-enabled": true,
    "script-torrent-done-enabled": false,
    "script-torrent-done-filename": "",
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 100,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 100,
    "speed-limit-up-enabled": false,
    "start-added-torrents": true,
    "trash-original-torrent-files": false,
    "umask": 2,
    "upload-slots-per-torrent": 14,
    "utp-enabled": true
}
EOF

chown ${SERVICE_USER}:${SERVICE_USER} ${CONFIG_DIR}/settings.json
chmod 600 ${CONFIG_DIR}/settings.json

###########################################
# 创建 systemd 服务
###########################################
print_info "创建 systemd 服务..."
cat > /etc/systemd/system/transmission-daemon.service <<EOF
[Unit]
Description=Transmission BitTorrent Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=${SERVICE_USER}
Group=${SERVICE_USER}
ExecStart=${BIN_DIR}/transmission-daemon -f -g ${CONFIG_DIR}
ExecReload=/bin/kill -s HUP \$MAINPID
NoNewPrivileges=true
MemoryDenyWriteExecute=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${downloads} ${CONFIG_DIR} /var/lib/transmission-daemon
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable transmission-daemon >/dev/null 2>&1

###########################################
# 第三方 Web 模板选择
###########################################
echo -e "\n${BlueBG}   Web 界面模板选择   ${Font}"
echo "1) 使用官方默认 Web 界面"
echo "2) 安装 TrguiNG 第三方 Web 界面 (推荐，功能更强大)"
read -p "请选择 (1/2, 默认 2, 10秒后自动选择): " -t 10 web_choice
echo

web_choice=${web_choice:-2}

if [[ ${web_choice} == "2" ]]; then
    print_info "正在安装 TrguiNG Web 界面..."
    
    # 备份原始 Web 界面
    if [ -d "${WEB_DIR}" ]; then
        backup_dir="${WEB_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        mv ${WEB_DIR} ${backup_dir}
        print_info "原 Web 界面已备份至: ${backup_dir}"
    fi
    
    # 下载最新版本
    cd /tmp
    rm -rf TrguiNG transmission-web-control
    
    # 尝试多种安装方式
    WEB_INSTALLED=false
    
    # 方法1: 从 GitHub 克隆
    print_info "尝试从 GitHub 克隆仓库..."
    if timeout 60 git clone --depth=1 https://github.com/ManuZhu0728/TrguiNG.git 2>/dev/null; then
        if [ -d "TrguiNG/web" ]; then
            mkdir -p ${WEB_DIR}
            cp -r TrguiNG/web/* ${WEB_DIR}/
            WEB_INSTALLED=true
            print_success "TrguiNG Web 界面安装成功 (从源码)"
        fi
    fi
    
    # 方法2: 尝试下载 Release
    if [ "$WEB_INSTALLED" = false ]; then
        print_info "尝试从 Releases 下载..."
        LATEST_URL=$(curl -s https://api.github.com/repos/ManuZhu0728/TrguiNG/releases/latest 2>/dev/null | grep "browser_download_url.*zip" | cut -d '"' -f 4 | head -n 1)
        
        if [ -n "$LATEST_URL" ]; then
            if wget -q --show-progress "$LATEST_URL" -O trguiNG.zip; then
                mkdir -p ${WEB_DIR}
                unzip -q trguiNG.zip -d ${WEB_DIR}
                WEB_INSTALLED=true
                print_success "TrguiNG Web 界面安装成功 (从 Release)"
            fi
        fi
    fi
    
    # 方法3: 使用传统的 transmission-web-control
    if [ "$WEB_INSTALLED" = false ]; then
        print_warning "TrguiNG 下载失败，尝试安装 transmission-web-control..."
        if timeout 60 git clone --depth=1 https://github.com/ronggang/transmission-web-control.git 2>/dev/null; then
            if [ -d "transmission-web-control/src" ]; then
                mkdir -p ${WEB_DIR}
                cp -r transmission-web-control/src/* ${WEB_DIR}/
                WEB_INSTALLED=true
                print_success "Transmission Web Control 安装成功"
            fi
        fi
    fi
    
    # 如果都失败，恢复原界面
    if [ "$WEB_INSTALLED" = false ]; then
        print_warning "所有第三方界面下载失败，使用官方默认界面"
        if [ -d "${backup_dir}" ]; then
            mv ${backup_dir} ${WEB_DIR}
        fi
    fi
    
    # 清理临时文件
    rm -rf /tmp/TrguiNG /tmp/transmission-web-control /tmp/trguiNG.zip
else
    print_info "使用官方默认 Web 界面"
fi

###########################################
# 启动服务
###########################################
print_info "启动 Transmission 服务..."
systemctl start transmission-daemon

# 等待服务启动
sleep 5

# 检查服务状态
if systemctl is-active --quiet transmission-daemon; then
    print_success "Transmission 服务启动成功！"
else
    print_error "Transmission 服务启动失败"
    echo "查看日志: journalctl -xeu transmission-daemon --no-pager -n 50"
    journalctl -xeu transmission-daemon --no-pager -n 50
    exit 1
fi

###########################################
# 清理临时文件
###########################################
print_info "清理临时文件..."
cd /tmp
rm -rf transmission-${TRANSMISSION_VERSION}*

###########################################
# 显示安装信息
###########################################
SERVER_IP=$(curl -4 -s --max-time 5 ip.sb 2>/dev/null || curl -4 -s --max-time 5 icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

echo -e "\n${GreenBG}========================================${Font}"
echo -e "${GreenBG}   Transmission 4.0.5 安装完成！   ${Font}"
echo -e "${GreenBG}========================================${Font}\n"

echo -e "${SkyBlue}【安装路径信息】${Font}"
echo -e "  程序目录:     ${Green}${BIN_DIR}${Font}"
echo -e "  配置文件:     ${Green}${CONFIG_DIR}/settings.json${Font}"
echo -e "  Web 模板:     ${Green}${WEB_DIR}${Font}"
echo -e "  下载目录:     ${Green}${downloads}${Font}"
echo -e "  未完成目录:   ${Green}${downloads}/incomplete${Font}"
echo -e "  服务用户:     ${Green}${SERVICE_USER}${Font}\n"

echo -e "${SkyBlue}【Web 管理界面】${Font}"
echo -e "  访问地址: ${Green}http://${SERVER_IP}:${rpcport}${Font}"
echo -e "  用户名:   ${RedBG} ${username} ${Font}"
echo -e "  密码:     ${RedBG} ${passwd} ${Font}\n"

echo -e "${SkyBlue}【服务管理命令】${Font}"
echo -e "  启动服务: ${Green}systemctl start transmission-daemon${Font}"
echo -e "  停止服务: ${Green}systemctl stop transmission-daemon${Font}"
echo -e "  重启服务: ${Green}systemctl restart transmission-daemon${Font}"
echo -e "  查看状态: ${Green}systemctl status transmission-daemon${Font}"
echo -e "  查看日志: ${Green}journalctl -u transmission-daemon -f${Font}\n"

echo -e "${SkyBlue}【修改下载目录】${Font}"
echo -e "  1. 停止服务: ${Green}systemctl stop transmission-daemon${Font}"
echo -e "  2. 编辑配置: ${Green}nano ${CONFIG_DIR}/settings.json${Font}"
echo -e "  3. 修改 download-dir 和 incomplete-dir 参数"
echo -e "  4. 创建目录: ${Green}mkdir -p /新目录${Font}"
echo -e "  5. 设置权限: ${Green}chown -R ${SERVICE_USER}:${SERVICE_USER} /新目录${Font}"
echo -e "  6. 启动服务: ${Green}systemctl start transmission-daemon${Font}\n"

echo -e "${Yellow}提示: 请妥善保管用户名和密码！${Font}"
echo -e "${Yellow}提示: 所有配置信息已保存到 /root/transmission_info.txt${Font}\n"

# 保存信息到文件
cat > /root/transmission_info.txt <<EOF
========================================
Transmission 4.0.5 安装信息
========================================
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
系统版本: $OS $VER

【路径信息】
程序目录:     ${BIN_DIR}
配置文件:     ${CONFIG_DIR}/settings.json
Web 模板:     ${WEB_DIR}
下载目录:     ${downloads}
未完成目录:   ${downloads}/incomplete
服务用户:     ${SERVICE_USER}

【访问信息】
Web 地址:     http://${SERVER_IP}:${rpcport}
用户名:       ${username}
密码:         ${passwd}
Web 端口:     ${rpcport}
Peer 端口:    ${peerport}

【服务管理】
启动: systemctl start transmission-daemon
停止: systemctl stop transmission-daemon
重启: systemctl restart transmission-daemon
状态: systemctl status transmission-daemon
日志: journalctl -u transmission-daemon -f

【修改下载目录步骤】
1. systemctl stop transmission-daemon
2. nano ${CONFIG_DIR}/settings.json
   修改 download-dir 和 incomplete-dir
3. mkdir -p /新目录
4. chown -R ${SERVICE_USER}:${SERVICE_USER} /新目录
5. systemctl start transmission-daemon

【卸载方法】
1. systemctl stop transmission-daemon
2. systemctl disable transmission-daemon
3. rm -rf ${BIN_DIR}/transmission-*
4. rm -rf ${WEB_DIR}
5. rm -rf ${CONFIG_DIR}
6. rm -rf ${downloads}
7. rm /etc/systemd/system/transmission-daemon.service
8. systemctl daemon-reload
9. userdel ${SERVICE_USER}

【技术支持】
GitHub: https://github.com/transmission/transmission
文档: https://github.com/transmission/transmission/wiki
EOF

chmod 600 /root/transmission_info.txt

print_success "安装信息已保存到: ${Green}/root/transmission_info.txt${Font}\n"
