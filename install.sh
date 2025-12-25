#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
cyan='\033[0;36m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

install_base() {
    apt update -y && apt install wget curl tar cron socat net-tools -y || yum install wget curl tar cron socat net-tools -y
}

# 从仓库下载彩色管理脚本并创建快捷方式
create_shortcut() {
    rm -f /usr/bin/x-ui

    echo -e "${yellow}正在下载最新的彩色管理脚本 x-ui.sh ...${plain}"
    wget -O /usr/local/x-ui/x-ui.sh https://raw.githubusercontent.com/yosituta/3x-ui/main/x-ui.sh -q --no-check-certificate

    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载管理脚本失败！（可能仓库已删除该文件）${plain}"
        echo -e "${yellow}备用手动下载：wget -O /usr/local/x-ui/x-ui.sh https://raw.githubusercontent.com/yosituta/3x-ui/main/x-ui.sh${plain}"
        echo -e "${yellow}然后运行：bash /usr/local/x-ui/x-ui.sh 进入菜单${plain}"
        return 1
    fi

    chmod +x /usr/local/x-ui/x-ui.sh
    ln -sf /usr/local/x-ui/x-ui.sh /usr/bin/x-ui
    echo -e "${green}管理脚本下载并链接成功！输入 x-ui 将显示版本并进入彩色菜单${plain}"
}

show_install_info() {
    local vps_ip=$(curl -s4m 8 https://api.ipify.org || curl -s6m 8 https://api64.ipify.org)
    [[ "$vps_ip" == *":"* ]] && vps_ip="[$vps_ip]"
    local local_port=$((RANDOM % 30000 + 20000))
    local panel_port=${config_port:-54321}
    local safe_path=${config_base_path}

    echo -e "\n${green}3x-ui 面板安装成功！${plain}"
    echo -e "------------------------------------------------------"
    echo -e "${cyan}【推荐安全访问】${plain}"
    echo -e "SSH 隧道：${yellow}ssh -L ${local_port}:127.0.0.1:${panel_port} root@${vps_ip}${plain}"
    echo -e "浏览器访问：${green}http://127.0.0.1:${local_port}${safe_path}${plain}"
    echo -e "------------------------------------------------------"
    echo -e "${cyan}【面板管理】${plain}"
    echo -e "命令：${green}x-ui${plain} → 显示版本后进入彩色交互菜单"
    echo -e "备用：${green}bash /usr/local/x-ui/x-ui.sh${plain}"
    echo -e "------------------------------------------------------"
    echo -e "${cyan}【域名 + HTTPS】${plain}"
    echo -e "1. 输入 ${green}x-ui${plain} 进入菜单"
    echo -e "2. 选择 SSL 证书管理（通常 16/18）"
    echo -e "3. 申请并绑定证书"
    echo -e "完成后用 https://域名:${panel_port}${safe_path} 访问"
    echo -e "------------------------------------------------------"
}

install_x-ui() {
    systemctl stop x-ui 2>/dev/null

    arch=$(arch)
    if [[ $arch == "x86_64" || $arch == "amd64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        arch="arm64"
    else
        arch="amd64"
        echo -e "${red}未知架构，尝试 amd64${plain}"
    fi

    last_version=$(curl -Ls "https://api.github.com/repos/yosituta/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [[ ! -n "$last_version" ]]; then
        echo -e "${red}检测版本失败${plain}"
        exit 1
    fi

    echo -e "下载版本：${green}${last_version}${plain}"
    wget -N "https://github.com/yosituta/3x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"

    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载失败，请检查 Release 文件${plain}"
        exit 1
    fi

    rm -rf /usr/local/x-ui/
    tar zxvf x-ui-linux-${arch}.tar.gz -C /usr/local/
    rm -f x-ui-linux-${arch}.tar.gz

    cd /usr/local/x-ui/
    chmod +x x-ui bin/xray-linux-${arch}

    cp -f x-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "\n${yellow}设置初始参数（回车默认）${plain}"
    read -p "账号 (默认 admin): " config_account
    [[ -z "$config_account" ]] && config_account="admin"
    read -p "密码 (默认 admin): " config_password
    [[ -z "$config_password" ]] && config_password="admin"
    read -p "端口 (默认 54321): " config_port
    [[ -z "$config_port" ]] && config_port="54321"
    read -p "路径 (默认 /): " config_base_path
    [[ -z "$config_base_path" ]] && config_base_path="/"

    [[ "${config_base_path:0:1}" != "/" ]] && config_base_path="/${config_base_path}"
    [[ "${config_base_path: -1}" != "/" ]] && config_base_path="${config_base_path}/"

    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} -port ${config_port} -webBasePath ${config_base_path}
    systemctl restart x-ui

    create_shortcut
    show_install_info
}

install_base
install_x-ui
