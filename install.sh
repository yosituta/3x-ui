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

# 核心修复：强制链接你项目压缩包里的彩色 x-ui.sh 脚本
create_shortcut() {
    # 1. 彻底删除可能存在的任何冲突
    rm -f /usr/bin/x-ui
    
    # 2. 检查压缩包里解压出来的 x-ui.sh 是否存在
    if [[ -f "/usr/local/x-ui/x-ui.sh" ]]; then
        chmod +x /usr/local/x-ui/x-ui.sh
        # 强制创建软链接，让 x-ui 命令直接运行这个彩色脚本
        ln -sf /usr/local/x-ui/x-ui.sh /usr/bin/x-ui
        echo -e "${green}已成功链接管理脚本到 /usr/bin/x-ui${plain}"
    else
        # 兜底：如果文件不存在，创建一个跳转脚本
        cat > /usr/bin/x-ui <<EOF
#!/bin/bash
/usr/local/x-ui/x-ui "\$@"
EOF
        chmod +x /usr/bin/x-ui
    fi
}

show_install_info() {
    local vps_ip=$(curl -s4m 8 https://api.ipify.org || curl -s6m 8 https://api64.ipify.org)
    [[ "$vps_ip" == *":"* ]] && vps_ip="[$vps_ip]"
    local local_port=$((RANDOM % 30000 + 20000))
    local panel_port=${config_port:-54321}
    local safe_path=${config_base_path}
    
    echo -e "\n${green}3x-ui 面板安装成功！${plain}"
    echo -e "------------------------------------------------------"
    echo -e "SSH 隧道安全登录 (推荐):"
    echo -e "${yellow}ssh -L ${local_port}:127.0.0.1:${panel_port} root@${vps_ip}${plain}"
    echo -e "登录后浏览器访问: ${green}http://127.0.0.1:${local_port}${safe_path}${plain}"
    echo -e "------------------------------------------------------"
    echo -e "${cyan}【域名访问与 HTTPS 配置】${plain}"
    echo -e "如果您想使用域名直接访问，请按照以下步骤操作："
    echo -e "1. 在终端输入: ${green}x-ui${plain}"
    echo -e "2. 输入数字: ${yellow}18${plain} (SSL 证书管理)"
    echo -e "3. 选择数字: ${yellow}1${plain} (申请证书并自动绑定)"
    echo -e "完成后，您即可通过 https://您的域名:${panel_port}${safe_path} 访问。"
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
        echo -e "${red}检测到未知的架构，尝试使用 amd64${plain}"
    fi
    
    # 从你的项目仓库检测最新版本
    last_version=$(curl -Ls "https://api.github.com/repos/yosituta/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ ! -n "$last_version" ]]; then
        echo -e "${red}检测版本失败，请检查网络或仓库 Release 状态${plain}"
        exit 1
    fi

    echo -e "正在从您的仓库下载最新版本: ${last_version}"
    wget -N "https://github.com/yosituta/3x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载失败，请确保 Release 中存在 x-ui-linux-${arch}.tar.gz 文件${plain}"
        exit 1
    fi

    rm -rf /usr/local/x-ui/
    tar zxvf x-ui-linux-${arch}.tar.gz -C /usr/local/
    rm x-ui-linux-${arch}.tar.gz -f
    
    cd /usr/local/x-ui/
    chmod +x x-ui bin/xray-linux-${arch}
    [[ -f "x-ui.sh" ]] && chmod +x x-ui.sh
    
    cp -f x-ui.service /etc/systemd/system/
    systemctl daemon-reload && systemctl enable x-ui && systemctl start x-ui
    
    echo -e "\n${yellow}请设置面板初始化参数：${plain}"
    read -p "设置账户 (默认 admin): " config_account
    [[ -z "$config_account" ]] && config_account="admin"
    read -p "设置密码 (默认 admin): " config_password
    [[ -z "$config_password" ]] && config_password="admin"
    read -p "设置端口 (默认 54321): " config_port
    [[ -z "$config_port" ]] && config_port="54321"
    read -p "设置路径 (默认 /): " config_base_path
    [[ -z "$config_base_path" ]] && config_base_path="/"
    
    [[ "${config_base_path:0:1}" != "/" ]] && config_base_path="/${config_base_path}"
    [[ "${config_base_path: -1}" != "/" ]] && config_base_path="${config_base_path}/"

    # 写入设置
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} -port ${config_port} -webBasePath ${config_base_path}
    systemctl restart x-ui

    create_shortcut
    show_install_info
}

install_base
install_x-ui
