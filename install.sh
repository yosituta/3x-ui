#!/bin/bash

# ==========================================================
# 3x-UI 旧免费版本一键安装脚本 (yosituta/3x-ui main, amd64 only)
# 使用: wget https://raw.githubusercontent.com/yosituta/3x-ui/main/install.sh && bash install.sh
# ==========================================================

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Please run as root (sudo bash install.sh)${plain}\n" && exit 1

# ----------------------------------------------------------
# OS 和架构检查 (仅 amd64)
# ----------------------------------------------------------
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo -e "${red}Unsupported OS${plain}" && exit 1
fi

arch() {
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        * ) echo -e "${red}Only Linux amd64 supported!${plain}" && exit 1 ;;
    esac
}

if [[ $(arch) != "amd64" ]]; then
    echo -e "${red}Error: This version only supports amd64. Use x86_64 server.${plain}"
    exit 1
fi

os_version=$(grep -i version_id /etc/os-release | cut -d '"' -f2 | cut -d . -f1)
if [[ "${release}" == "ubuntu" && ${os_version} -lt 20 ]] || [[ "${release}" == "debian" && ${os_version} -lt 11 ]] || [[ "${release}" == "centos" && ${os_version} -lt 8 ]]; then
    echo -e "${red}OS version too low, please upgrade.${plain}" && exit 1
fi

# ----------------------------------------------------------
# 安装基础依赖
# ----------------------------------------------------------
install_base() {
    case "${release}" in
        ubuntu | debian)
            apt-get update && apt-get install -y wget curl tar tzdata unzip
            ;;
        centos | rhel)
            yum update -y && yum install -y wget curl tar tzdata unzip
            ;;
        *)
            echo -e "${red}Unsupported OS: $release${plain}" && exit 1
            ;;
    esac
}

# ----------------------------------------------------------
# 生成随机凭证
# ----------------------------------------------------------
gen_random_string() {
    LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "${1:-16}" | head -n 1
}

# ----------------------------------------------------------
# 安装逻辑 (优化: 临时二进制名, WorkingDirectory, unzip 支持)
# ----------------------------------------------------------
install_3xui() {
    echo -e "${green}Installing 3x-UI Old Free Version (amd64 only, no updates)${plain}"
    repo_url="https://raw.githubusercontent.com/yosituta/3x-ui/main"

    install_base

    cd /usr/local/
    # 停止并移除旧版
    systemctl stop x-ui 2>/dev/null || true
    rm -rf x-ui

    # 下载文件 (临时名避免覆盖目录)
    echo -e "${green}Downloading components...${plain}"
    wget -N --no-check-certificate "${repo_url}/x-ui.sh" -O /usr/bin/x-ui && chmod +x /usr/bin/x-ui
    wget -N --no-check-certificate "${repo_url}/x-ui" -O x-ui-binary && chmod +x x-ui-binary
    wget -N --no-check-certificate "${repo_url}/x-ui.service" -O x-ui.service

    # 创建目录并移动二进制
    mkdir -p x-ui/bin
    mv x-ui-binary x-ui/x-ui
    cd x-ui

    # 下载 bin 文件 (Xray 等)
    wget -N --no-check-certificate "${repo_url}/bin/xray-linux-amd64" -O bin/xray-linux-amd64 && chmod +x bin/xray-linux-amd64
    wget -N --no-check-certificate "${repo_url}/bin/geoip.dat" -O bin/geoip.dat || true
    wget -N --no-check-certificate "${repo_url}/bin/geosite.dat" -O bin/geosite.dat || true

    # systemd 服务 (内置 WorkingDirectory 修复 Xray 路径)
    cp ../x-ui.service /etc/systemd/system/
    cat > /etc/systemd/system/x-ui.service << 'SERVICE_EOF'
[Unit]
Description=3x-UI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    # 设置随机凭证
    username=$(gen_random_string 8)
    password=$(gen_random_string 12)
    ./x-ui setting -username "${username}" -password "${password}" -port 54321

    echo -e "${green}Installation complete!${plain}"
    echo -e "Panel URL: http://$(curl -4 -s ifconfig.me):54321 (IPv4 preferred, use SSH tunnel for localhost)"
    echo -e "Username: ${username}"
    echo -e "Password: ${password}"
    echo -e "${yellow}Change credentials immediately! Command: x-ui setting${plain}"
    echo -e "${blue}Management: x-ui start/stop/restart/status${plain}"
    echo -e "${yellow}For public access, set SSL cert or use SSH tunnel.${plain}"
}

# 运行
install_3xui