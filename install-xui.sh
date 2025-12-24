#!/bin/bash
# X-UI手动安装脚本 - 一键下载zip + 解压 + 安装
# 用法: curl -L https://raw.githubusercontent.com/yosituta/3x-ui/main/install-xui.sh | bash

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
    ${system_package} install -y curl wget unzip jq -y >/dev/null 2>&1
}

install_core() {
    yellow "下载x-ui.zip..."
    cd /root/
    wget https://github.com/yosituta/3x-ui/releases/download/3x-ui/x-ui.zip -O x-ui.zip || { red "下载失败！"; exit 1; }

    yellow "解压x-ui.zip..."
    unzip -o x-ui.zip  # -o覆盖
    rm x-ui.zip  # 清理zip
    if [ ! -d "x-ui" ]; then { red "解压失败！"; exit 1; }; fi

    yellow "准备权限..."
    cd /root/  # 切换到root目录
    chmod +x x-ui/x-ui x-ui/bin/xray-linux-amd64 x-ui/x-ui.sh  # xray-linux-amd64根据架构调整

    yellow "清理旧安装..."
    rm -rf /usr/local/x-ui/ /usr/bin/x-ui

    yellow "复制文件..."
    cp x-ui/x-ui.sh /usr/bin/x-ui  # 复制管理脚本
    cp -f x-ui/x-ui.service /etc/systemd/system/  # 复制systemd服务
    mv x-ui/ /usr/local/  # 移动整个x-ui目录

    yellow "启动服务..."
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl restart x-ui

    yellow "检查状态..."
    sleep 3
    x-ui status

    # 防火墙放行
    yellow "放行端口54321..."
    if command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-port=54321/tcp && firewall-cmd --reload
    elif command -v ufw >/dev/null; then
        ufw allow 54321/tcp && ufw reload
    else
        iptables -I INPUT -p tcp --dport 54321 -j ACCEPT
        iptables-save > /etc/iptables.rules
    fi
    green "端口已放行。"
}

main() {
    echo -e "\n${green}一键安装X-UI...${yellow}"
    install_deps
    install_core
    IP=$(curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')
    echo -e "\n${green}安装成功！${yellow}"
    echo "地址: http://${IP}:54321"
    echo "用户名/密码: admin/admin (立即修改: x-ui user)"
    echo "端口冲突? x-ui setting 修改端口，然后 x-ui restart"
    echo "菜单: x-ui"
    echo "日志: x-ui log"
}

main "$@"