#!/bin/bash
# 自定义3X-UI一键安装脚本 - 从您的GitHub仓库拉取
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
    ${system_package} install -y curl wget unzip git jq >/dev/null 2>&1
}

install_core() {
    yellow "拉取自定义3X-UI..."
    rm -rf /usr/local/x-ui /usr/bin/x-ui
    git clone https://github.com/yosituta/3x-ui.git /tmp/x-ui-src --depth=1
    cd /tmp/x-ui-src
    cp x-ui.sh /usr/bin/x-ui
    chmod +x /usr/bin/x-ui
    cp x-ui.service /etc/systemd/system/
    mv x-ui/ /usr/local/
    ARCH=$(uname -m)
    if [[ $ARCH == "x86_64" ]]; then XRAY_BIN="xray-linux-64"; fi
    if [[ $ARCH == "aarch64" ]]; then XRAY_BIN="xray-linux-arm64"; fi
    chmod +x /usr/local/x-ui/bin/${XRAY_BIN}*
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
        iptables -I INPUT -p tcp --dport 54321 -j ACCEPT && iptables-save > /etc/iptables.rules
    fi
    green "端口已放行。"
}

main() {
    echo -e "\n$$ {green}安装自定义3X-UI... $${yellow}"
    install_deps
    install_core
    firewall_setting
    IP=$(curl -s ipinfo.io/ip)
    echo -e "\n$$ {green}成功！ $${yellow}"
    echo "地址: http://${IP}:54321"
    echo "用户名/密码: admin/admin"
    echo "修改: x-ui user"
}

main "$@"