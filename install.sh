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
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= "]+' '/VERSION_ID/{print $2}' /etc/os-release)
fi

if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= "]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
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

# This function will be called when user installed x-ui
config_after_install() {
    echo -e "${yellow}为了安全性，建议修改面板端口和登录用户名密码${plain}"
    read -p "确认是否修改设置 [y/n] (默认 n): " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名: " config_account
        echo -e "${yellow}您的账户名将设定为: ${config_account}${plain}"
        read -p "请设置您的账户密码: " config_password
        echo -e "${yellow}您的账户密码将设定为: ${config_password}${plain}"
        read -p "请设置面板访问端口: " config_port
        echo -e "${yellow}您的面板访问端口将设定为: ${config_port}${plain}"
        read -p "请设置面板根路径 (例: /test/，默认为空): " config_base_path
        [[ -z "${config_base_path}" ]] && config_base_path="/"
        if [[ "${config_base_path:0:1}" != "/" ]]; then
            config_base_path="/${config_base_path}"
        fi
        if [[ "${config_base_path: -1}" != "/" ]]; then
            config_base_path="${config_base_path}/"
        fi
        echo -e "${yellow}您的面板根路径将设定为: ${config_base_path}${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} -port ${config_port} -webBasePath ${config_base_path}
    else
        echo -e "${red}已跳过设置，使用默认配置${plain}"
        config_account="admin"
        config_password="admin"
        config_port="54321"
        config_base_path="/"
    fi
}

# 核心提示函数
show_install_info() {
    # 1. IP获取逻辑：优先 IPv4，无 IPv4 则获取 IPv6
    local vps_ip=$(curl -s4m 8 https://api.ipify.org || curl -s4m 8 https://checkip.amazonaws.com)
    local display_ip=""
    
    if [[ -z "${vps_ip}" ]]; then
        vps_ip=$(curl -s6m 8 https://api64.ipify.org || curl -s6m 8 https://checkip.amazonaws.com)
        display_ip="[${vps_ip}]"
    else
        display_ip="${vps_ip}"
    fi
    
    # 2. 随机生成本地映射端口 (10000-60000)
    local local_port=$((RANDOM % 50001 + 10000))
    
    # 3. 参数衔接
    local panel_port=${config_port:-54321}
    local display_username=${config_account:-admin}
    local display_password=${config_password:-admin}
    local display_path=${config_base_path:-"/"}

    echo -e "\n${green}检测到为全新安装，出于安全考虑已生成登录信息：${plain}"
    echo -e "#####################################################"
    echo -e "${yellow}用户名 : ${plain} ${display_username}"
    echo -e "${yellow}密  码 : ${plain} ${display_password}"
    echo -e "${yellow}访问路径: ${plain} ${display_path}"
    echo -e "#####################################################"
    echo -e "如果您忘记了登录信息，可以在安装后通过 x-ui 命令然后输入数字 10 选项进行查看"
    echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo ""
    echo -e "${red}警告：未找到证书和密钥，面板传输不安全！${plain}"
    echo ""
    echo -e "------- >>>> 推荐方法：使用 SSH 端口转发登录 <<<< -------"
    echo ""
    echo -e "1、本地电脑(Windows/Mac)打开终端执行：\n   ${green}ssh -L ${local_port}:127.0.0.1:${panel_port} root@${display_ip}${plain}"
    echo ""
    echo -e "2、成功输入服务器 root 密码后，保持该终端窗口不要关闭"
    echo ""
    echo -e "3、在本地浏览器地址栏输入并访问：\n   ${green}http://127.0.0.1:${local_port}${display_path}${plain}"
    echo ""
    echo -e "注意：此方式通过 SSH 加密隧道传输，比直接访问公网 IP 更安全且不易被阻断。"
    echo "------------------------------------------------------"
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if  [ $# -gt 0 ] ;then
        package_url="https://github.com/yosituta/3x-ui/releases/download/$1/x-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 3x-ui $1"
    else
        last_version=$(curl -Ls "https://api.github.com/repos/yosituta/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 3x-ui 版本失败，可能是超出 GitHub API 限制，请稍后再试${plain}"
            exit 1
        fi
        echo -e "检测到 3x-ui 最新版本: ${last_version}，开始安装"
        package_url="https://github.com/yosituta/3x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
    fi

    if [ -e /usr/local/x-ui/ ]; then
        rm /usr/local/x-ui/ -rf
    fi

    wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${package_url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 3x-ui 失败，请确保您的服务器能够下载 Github 的文件${plain}"
        exit 1
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}3x-ui ${last_version}${plain} 安装完成，面板已启动"
    
    config_after_install
    show_install_info
}

echo -e "${green}开始安装...${plain}"
install_base
install_x-ui $1
