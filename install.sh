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
    
    # 3
