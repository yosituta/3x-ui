#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
else
    release="debian"
fi

arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
fi

echo "架构: ${arch}"

# 修复版本号检测逻辑
os_version=""
if [[ -f /etc/os-release ]]; then
    # 提取主版本号，例如 20.04 -> 20
    os_version=$(awk -F'[= "]+' '/VERSION_ID/{print $2}' /etc/os-release | cut -d'.' -f1)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -lt 7 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat -y
    else
        apt update -y
        apt install wget curl tar cron socat -y
    fi
}

show_install_info() {
    local vps_ip=$(curl -s4m 8 https://api.ipify.org || curl -s4m 8 https://checkip.amazonaws.com)
    local display_ip=""
    if [[ -z "${vps_ip}" ]]; then
        vps_ip=$(curl -s6m 8 https://api64.ipify.org || curl -s6m 8 https://checkip.amazonaws.com)
        display_ip="[${vps_ip}]"
    else
        display_ip="${vps_ip}"
    fi
    local local_port=$((RANDOM % 50001 + 10000))
    local panel_port=${config_port:-54321}
    local display_path=${config_base_path:-"/"}

    echo -e "\n${green}3x-ui 安装完成，面板已启动${plain}"
    echo -e "#####################################################"
    echo -e "${yellow}用户名 : ${plain} ${config_account:-admin}"
    echo -e "${yellow}密  码 : ${plain} ${config_password:-admin}"
    echo -e "${yellow}访问路径: ${plain} ${display_path}"
    echo -e "#####################################################"
    echo -e "------- >>>> 推荐方法：使用 SSH 端口转发登录 <<<< -------"
    echo -e "1、本地电脑打开终端执行：${green}ssh -L ${local_port}:127.0.0.1:${panel_port} root@${display_ip}${plain}"
    echo -e "2、输入密码成功登录后，请勿关闭终端"
    echo -e "3、在本地浏览器访问：${green}http://127.0.0.1:${local_port}${display_path}${plain}"
    echo "------------------------------------------------------"
}

create_shortcut() {
    cat > /usr/bin/x-ui <<EOF
#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

show_menu() {
    echo -e "\${green}3x-ui 管理脚本\${plain}"
    echo -e "--- 基础管理 ---"
    echo -e "1. 启动面板      2. 停止面板"
    echo -e "3. 重启面板      4. 查看状态"
    echo -e "--- 配置管理 ---"
    echo -e "10. 查看当前设置 (端口/账号/路径)"
    echo -e "11. 重置所有设置 (危险)"
    echo -e "0. 退出菜单"
    echo -e "----------------"
    read -p "请输入数字选择 [0-11]: " num
    case "\$num" in
        1) systemctl start x-ui && echo -e "\${green}已启动\${plain}" ;;
        2) systemctl stop x-ui && echo -e "\${yellow}已停止\${plain}" ;;
        3) systemctl restart x-ui && echo -e "\${green}已重启\${plain}" ;;
        4) systemctl status x-ui ;;
        10) /usr/local/x-ui/x-ui setting -show ;;
        11) /usr/local/x-ui/x-ui setting -reset ;;
        0) exit 0 ;;
        *) echo -e "\${red}无效输入\${plain}" ;;
    esac
}

if [[ \$# -gt 0 ]]; then
    case "\$1" in
        start) systemctl start x-ui ;;
        stop) systemctl stop x-ui ;;
        restart) systemctl restart x-ui ;;
        status) systemctl status x-ui ;;
        setting) /usr/local/x-ui/x-ui setting "\${@:2}" ;;
        *) /usr/local/x-ui/x-ui setting -show ;;
    esac
else
    show_menu
fi
EOF
    chmod +x /usr/bin/x-ui
}

config_after_install() {
    echo -e "${yellow}为了安全性，建议修改面板端口和登录用户名密码${plain}"
    read -p "确认是否修改设置 [y/n] (默认 n): " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名: " config_account
        read -p "请设置您的账户密码: " config_password
        read -p "请设置面板访问端口: " config_port
        read -p "请设置面板根路径 (例: /test/): " config_base_path
        [[ -z "${config_base_path}" ]] && config_base_path="/"
        [[ "${config_base_path:0:1}" != "/" ]] && config_base_path="/${config_base_path}"
        [[ "${config_base_path: -1}" != "/" ]] && config_base_path="${config_base_path}/"
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
    if [[ -z "$last_version" ]]; then
        echo -e "${red}无法连接 GitHub API，请检查网络${plain}"
        exit 1
    fi
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

    create_shortcut
    config_after_install
    show_install_info
}

echo -e "${green}开始安装...${plain}"
install_base
install_x-ui
