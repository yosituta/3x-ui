#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

install_base() {
    apt update -y && apt install wget curl tar cron socat net-tools -y
}

# 核心修复：直接链接原厂最全的脚本
create_shortcut() {
    # 强制删除旧的
    rm -f /usr/bin/x-ui
    
    # 3x-ui 官方包内包含一个全功能的交互式脚本
    # 我们将其作为主命令，这会包含你想要的所有原厂菜单功能
    if [[ -f "/usr/local/x-ui/x-ui.sh" ]]; then
        ln -sf /usr/local/x-ui/x-ui.sh /usr/bin/x-ui
        chmod +x /usr/bin/x-ui
    else
        # 兜底方案：如果官方没带，我们手动构建一个能完美转发所有命令的入口
        cat > /usr/bin/x-ui <<EOF
#!/bin/bash
case "\$1" in
    start|stop|restart|status|enable|disable) systemctl \$1 x-ui ;;
    *) /usr/local/x-ui/x-ui "\$@" ;;
esac
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
    
    echo -e "\n${green}3x-ui 安装成功，原厂管理菜单已就绪${plain}"
    echo -e "------------------------------------------------------"
    echo -e "SSH 隧道命令: ${yellow}ssh -L ${local_port}:127.0.0.1:${panel_port} root@${vps_ip}${plain}"
    echo -e "浏览器访问: ${green}http://127.0.0.1:${local_port}${safe_path}${plain}"
    echo -e "------------------------------------------------------"
}

install_x-ui() {
    systemctl stop x-ui 2>/dev/null
    arch=$(arch)
    [[ $arch == "x86_64" || $arch == "amd64" ]] && arch="amd64" || arch="arm64"
    
    last_version=$(curl -Ls "https://api.github.com/repos/yosituta/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    wget -N "https://github.com/yosituta/3x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
    
    rm -rf /usr/local/x-ui/ && mkdir -p /usr/local/x-ui/
    tar zxvf x-ui-linux-${arch}.tar.gz -C /usr/local/
    rm x-ui-linux-${arch}.tar.gz -f
    
    cd /usr/local/x-ui/
    cp -f x-ui.service /etc/systemd/system/
    systemctl daemon-reload && systemctl enable x-ui && systemctl start x-ui
    
    # 交互设置
    read -p "账户 (默认 admin): " config_account
    [[ -z "$config_account" ]] && config_account="admin"
    read -p "密码 (默认 admin): " config_password
    [[ -z "$config_password" ]] && config_password="admin"
    read -p "端口 (默认 54321): " config_port
    [[ -z "$config_port" ]] && config_port="54321"
    read -p "路径 (例如 /x-ui/): " config_base_path
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
