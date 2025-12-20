#!/bin/bash
# 自定义3X-UI一键安装脚本 - 修正版，支持您的仓库结构
# 用法: bash install.sh

red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }

[ $(id -u) != "0" ] && { red "错误: 需要root权限！"; exit 1; }

if [[ -f /etc/redhat-release ]]; then
    release="centos"; system_package="yum"
elif cat /etc/issue | grep -Eqi "ubuntu|debian"; then
    release="ubuntu"; system_package="apt"
else
    red "不支持的系统！"; exit 1
fi

install_deps() {
    yellow "安装依赖..."
    ${system_package} update -y >/dev/null 2>&1
    ${system_package} install -y curl wget unzip git jq wget unzip -y >/dev/null 2>&1
}

install_core() {
    yellow "拉取自定义3X-UI..."
    rm -rf /usr/local/x-ui /usr/bin/x-ui /etc/systemd/system/x-ui.service
    git clone https://github.com/yosituta/3x-ui.git /tmp/x-ui-src --depth=1
    cd /tmp/x-ui-src || { red "克隆失败！"; exit 1; }

    # 复制核心文件（基于您的仓库结构）
    cp x-ui /usr/bin/x-ui  # 面板二进制
    cp x-ui.sh /usr/bin/x-ui  # 管理脚本覆盖（x-ui.sh -> x-ui）
    chmod +x /usr/bin/x-ui

    cp x-ui.service /etc/systemd/system/
    mkdir -p /usr/local/x-ui/bin
    if [ -d "bin" ]; then
        cp bin/* /usr/local/x-ui/bin/  # xray内核
        chmod +x /usr/local/x-ui/bin/*  # 架构自动（xray-linux-64等）
    fi

    # geo文件（如果仓库有，标准3X-UI需）
    if [ -f "geoip.dat" ]; then cp geoip.dat /usr/local/x-ui/; fi
    if [ -f "geosite.dat" ]; then cp geosite.dat /usr/local/x-ui/; fi

    cd /tmp && rm -rf x-ui-src
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    green "安装完成！"
}

firewall_setting() {
    yellow "放行端口54321..."
    if command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-port=54321/tcp && firewall-cmd --reload
    elif command -v ufw >/dev/null; then
        ufw allow 54321/tcp && ufw reload
    else
        iptables -I INPUT -p tcp --dport 54321 -j ACCEPT
        iptables-save > /etc/iptables.rules  # CentOS6等
    fi
    green "端口已放行。"
}

main() {
    echo -e "\n$$ {green}安装自定义3X-UI... $${yellow}"
    install_deps
    install_core
    firewall_setting
    IP=$(curl -s ipinfo.io/ip || echo "your-server-ip")
    echo -e "\n$$ {green}成功！ $${yellow}"
    echo "地址: http://${IP}:54321"
    echo "用户名/密码: admin/admin"
    echo "修改密码: x-ui user"
    echo "状态: x-ui status"
}

main "$@"