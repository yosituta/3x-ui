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

# check root (修正: 单 $EUID，无转义)
[[ $EUID -ne 0 ]] && echo -e "${red}请使用 root 权限运行 (sudo bash install.sh)${plain}\n" && exit 1

# ----------------------------------------------------------
# OS 和架构检查 (仅 amd64)
# ----------------------------------------------------------
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo -e "${red}不支持的 OS${plain}" && exit 1
fi

arch() {
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        * ) echo -e "${red}仅支持 Linux amd64 架构!${plain}" && exit 1 ;;
    esac
}

if [[ $(arch) != "amd64" ]]; then
    echo -e "${red}错误: 此版本仅支持 amd64. 请使用 x86_64 服务器.${plain}"
    exit 1
fi

os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
if [[ "${release}" == "ubuntu" && ${os_version} -lt 20 ]] || [[ "${release}" == "debian" && ${os_version} -lt 11 ]] || [[ "${release}" == "centos" && ${os_version} -lt 8 ]]; then
    echo -e "${red}OS 版本过低，请升级.${plain}" && exit 1
fi

# ----------------------------------------------------------
# 安装基础依赖
# ----------------------------------------------------------
install_base() {
    case "${release}" in
        ubuntu | debian)
            apt-get update && apt-get install -y wget curl tar tzdata
            ;;
        centos | rhel)
            yum update -y && yum install -y wget curl tar tzdata
            ;;
        *)
            echo -e "${red}不支持的 OS: $release${plain}" && exit 1
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
# 安装逻辑
# ----------------------------------------------------------
install_3xui() {
    echo -e "${green}安装 3x-UI 旧免费版本 (amd64 only, 无更新)${plain}"
    repo_url="https://raw.githubusercontent.com/yosituta/3x-ui/main"

    install_base

    cd /usr/local/
    # 下载并停止旧版
    systemctl stop x-ui 2>/dev/null || true
    rm -rf x-ui

    # 下载文件 (修正: 无转义，确保单 $)
    echo -e "${green}下载组件...${plain}"
    wget -N --no-check-certificate "${repo_url}/x-ui.sh" -O /usr/bin/x-ui && chmod +x /usr/bin/x-ui
    wget -N --no-check-certificate "${repo_url}/x-ui" -O x-ui && chmod +x x-ui
    wget -N --no-check-certificate "${repo_url}/x-ui.service" -O x-ui.service

    mkdir -p x-ui/bin
    cd x-ui
    wget -N --no-check-certificate "${repo_url}/bin/xray-linux-amd64" -O bin/xray-linux-amd64 && chmod +x bin/xray-linux-amd64
    wget -N --no-check-certificate "${repo_url}/bin/geoip.dat" -O bin/geoip.dat || true
    wget -N --no-check-certificate "${repo_url}/bin/geosite.dat" -O bin/geosite.dat || true

    # systemd 服务
    cp ../x-ui.service /etc/systemd/system/
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=3x-UI
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    # 设置默认凭证 (随机)
    username=$(gen_random_string 8)
    password=$(gen_random_string 12)
    /usr/local/x-ui/x-ui setting -username "${username}" -password "${password}" -port 54321

    echo -e "${green}安装完成!${plain}"
    echo -e "面板地址: http://$(curl -s ifconfig.me):54321"
    echo -e "用户名: ${username}"
    echo -e "密码: ${password}"
    echo -e "${yellow}立即修改凭证! 命令: x-ui setting${plain}"
    echo -e "${blue}管理: x-ui start/stop/restart/status${plain}"
}

# 运行
install_3xui