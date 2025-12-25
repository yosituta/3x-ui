#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
else
    release="debian"
fi

arch=$(arch)
[[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]] && arch="amd64"
[[ $arch == "aarch64" || $arch == "arm64" ]] && arch="arm64"

os_version=$(awk -F'[= "]+' '/VERSION_ID/{print $2}' /etc/os-release | cut -d'.' -f1)

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat -y
    else
        apt update -y
        apt install wget curl tar cron socat -y
    fi
}

# 关键：调用原厂菜单脚本
create_shortcut() {
    # 3x-ui 官方包解压后通常带有一个 x-ui.sh
    # 我们将其链接到 /usr/bin/x-ui
    if [[ -f /usr/local/x-ui/x-ui.sh ]]; then
        chmod +x /usr/local/x-ui/x-ui.sh
        ln -sf /usr/local/x-ui/x-ui.sh /usr/bin/x-ui
    else
        # 如果源码没带，我们手动创建一个能调出原厂二进制设置显示的脚本
        cat > /usr/bin/x-ui <<EOF
#!/bin/bash
/usr/local/x-ui/x-ui "\$@"
EOF
        chmod +x /usr/bin/x-ui
    fi
}

show_install_info() {
    local vps_ip=$(curl -s4m 8 https://api.ipify.org || curl -s4m 8 https://checkip.amazonaws.com)
    [[ -z "${vps_ip}" ]] && vps_ip=$(curl -s6m 8 https://api64.ipify.org)
    
    local local_port=$((RANDOM % 50001 + 10000))
    local panel_port=${config_port:-54321}
    local display_path=${config_base_path:-"/"}

    echo -e "\n${green}3x-ui 安装完成，原厂菜单已恢复${plain}"
    echo -e "#####################################################"
    echo -e "${yellow}用户名 : ${plain} ${config_account}"
    echo -e "${yellow}密  码 : ${plain} ${config_password}"
    echo -e "${yellow}访问路径: ${plain} ${display_path}"
    echo -e "#####################################################"
    echo -e "--- SSH 隧道安全访问指令 ---"
    echo -e "${cyan}1. 复制此命令并在本地运行: ${green}ssh -L ${local_port}:127.0.0.1:${panel_port} root@${vps_ip}${plain}"
    echo -e "${cyan}2. 浏览器访问: ${green}http://127.0.0.1:${local_port}${display_path}${plain}"
}

config_after_install() {
    read -p "确认是否修改设置 [y/n] (默认 n): " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "设置账户名: " config_account
        read -p "设置密码: " config_password
        read -p "设置端口: " config_port
        read -p "设置路径 (例: /test/): " config_base_path
        [[ -z "${config_base_path}" ]] && config_base_path="/"
        [[ "${config_base_path:0:1}" != "/" ]] && config_base_path="/${config_base_path}"
        [[ "${config_base_path: -1}" != "/" ]] && config_base_path="${config_base_path}/"
        # 强制设置一次，确保面板启动
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} -port ${config_port} -webBasePath ${config_base_path}
    else
        config_account="admin"
        config_password="admin"
        config_port="54321"
        config_base_path="/"
    fi
}

install_x-ui() {
    systemctl stop x-ui 2>/dev/null
    cd /usr/local/
    last_version=$(curl -Ls "https://api.github.com/repos/yosituta/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    package_url="https://github.com/yosituta/3x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
    
    rm -rf /usr/local/x-ui/
    wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${package_url}
    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    config_after_install
    create_shortcut
    show_install_info
}

install_base
install_x-ui
