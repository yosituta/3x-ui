#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

install_base() {
    apt update -y && apt install wget curl tar cron socat -y
}

# 彻底修复：让 x-ui status 完美显示状态
create_shortcut() {
    rm -f /usr/bin/x-ui
    cat > /usr/bin/x-ui <<EOF
#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

show_menu() {
    echo -e "\${green}3x-ui 面板管理脚本\${plain}"
    echo -e "--- 基础管理 ---"
    echo -e "\${green}1.\${plain} 启动面板      \${green}2.\${plain} 停止面板"
    echo -e "\${green}3.\${plain} 重启面板      \${green}4.\${plain} 查看状态"
    echo -e "--- 配置管理 ---"
    echo -e "\${green}10.\${plain} 查看当前设置"
    echo -e "\${green}11.\${plain} 修改账户密码"
    echo -e "\${green}12.\${plain} 修改面板端口"
    echo -e "\${green}0.\${plain} 退出菜单"
    echo -e "----------------"
    read -p "选择 [0-12]: " num
    case "\$num" in
        1) systemctl start x-ui ;;
        2) systemctl stop x-ui ;;
        3) systemctl restart x-ui ;;
        4) systemctl status x-ui ;;
        10) /usr/local/x-ui/x-ui setting -show ;;
        11) read -p "用户: " u && read -p "密码: " p && /usr/local/x-ui/x-ui setting -username \$u -password \$p && systemctl restart x-ui ;;
        12) read -p "端口: " port && /usr/local/x-ui/x-ui setting -port \$port && systemctl restart x-ui ;;
        0) exit 0 ;;
        *) /usr/local/x-ui/x-ui "\$@" ;;
    esac
}

# 关键修复逻辑：识别 status 命令并转给 systemctl
if [[ \$# -gt 0 ]]; then
    case "\$1" in
        status) systemctl status x-ui ;;
        start) systemctl start x-ui ;;
        stop) systemctl stop x-ui ;;
        restart) systemctl restart x-ui ;;
        reload) systemctl reload x-ui ;;
        *) /usr/local/x-ui/x-ui "\$@" ;;
    esac
else
    show_menu
fi
EOF
    chmod +x /usr/bin/x-ui
}

show_install_info() {
    local vps_ip=$(curl -s4m 8 https://api.ipify.org || curl -s6m 8 https://api64.ipify.org)
    [[ "$vps_ip" == *":"* ]] && vps_ip="[$vps_ip]"
    
    local local_port=$((RANDOM % 40000 + 20000))
    local panel_port=${config_port:-54321}
    
    local safe_path=${config_base_path}
    [[ "${safe_path:0:1}" != "/" ]] && safe_path="/${safe_path}"

    echo -e "\n${green}面板安装成功！${plain}"
    echo -e "------------------------------------------------------"
    echo -e "请在本地电脑执行此命令（按回车确认）:"
    echo -e "${yellow}ssh -L ${local_port}:127.0.0.1:${panel_port} root@${vps_ip}${plain}"
    echo -e "------------------------------------------------------"
    
    # 路径拼接显示修复
    local final_link="http://127.0.0.1:${local_port}${safe_path}"
    echo -e "登录地址: ${green}${final_link}${plain}"
    echo -e "用户名: ${green}${config_account}${plain} | 密码: ${green}${config_password}${plain}"
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
    
    echo -e "${yellow}设置面板参数：${plain}"
    read -p "账户 (默认 admin): " config_account
    [[ -z "$config_account" ]] && config_account="admin"
    read -p "密码 (默认 admin): " config_password
    [[ -z "$config_password" ]] && config_password="admin"
    read -p "端口 (默认 54321): " config_port
    [[ -z "$config_port" ]] && config_port="54321"
    read -p "路径 (例如 /x-ui/): " config_base_path
    [[ -z "$config_base_path" ]] && config_base_path="/"
    
    # 路径自动补全
    [[ "${config_base_path:0:1}" != "/" ]] && config_base_path="/${config_base_path}"
    [[ "${config_base_path: -1}" != "/" ]] && config_base_path="${config_base_path}/"

    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} -port ${config_port} -webBasePath ${config_base_path}
    systemctl restart x-ui

    create_shortcut
    show_install_info
}

install_base
install_x-ui
