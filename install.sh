#!/bin/bash
# X-Panel一键安装脚本 - 优化版，v25.9.25，支持通用架构IP访问
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
    ${system_package} install -y curl wget unzip git jq git-lfs -y >/dev/null 2>&1
}

install_core() {
    yellow "拉取自定义X-Panel v25.9.25..."
    rm -rf /usr/local/x-ui /usr/bin/x-ui /etc/systemd/system/x-ui.service
    git clone https://github.com/yosituta/3x-ui.git /tmp/x-ui-src --depth=1
    cd /tmp/x-ui-src || { red "克隆失败！"; exit 1; }

    # LFS拉大文件
    git lfs install --local >/dev/null 2>&1
    git lfs pull >/dev/null 2>&1
    if [ ! -f "x-ui" ] || file x-ui | grep -q "text"; then
        yellow "LFS失败，备用下载v25.9.25二进制..."
        ARCH=$(uname -m)
        if [[ $ARCH == "x86_64" ]]; then
            wget https://github.com/MHSanaei/3x-ui/releases/download/v25.9.25/x-ui-linux-amd64.tar.gz -O /tmp/x-ui.tar.gz >/dev/null 2>&1
        elif [[ $ARCH == "aarch64" ]]; then
            wget https://github.com/MHSanaei/3x-ui/releases/download/v25.9.25/x-ui-linux-arm64.tar.gz -O /tmp/x-ui.tar.gz >/dev/null 2>&1
        else
            red "不支持架构: $ARCH"; exit 1
        fi
        if [ -f /tmp/x-ui.tar.gz ]; then
            tar -xzf /tmp/x-ui.tar.gz -C . x-ui
            rm /tmp/x-ui.tar.gz
        fi
    fi

    # 验证二进制
    if file x-ui | grep -q "ELF"; then
        green "二进制验证OK"
    else
        red "二进制错误！"; exit 1
    fi

    # 复制文件
    mkdir -p /usr/local/x-ui/bin /usr/local/x-ui/db
    cp x-ui.sh /usr/bin/x-ui && chmod +x /usr/bin/x-ui
    cp x-ui /usr/local/x-ui/x-ui && chmod +x /usr/local/x-ui/x-ui
    cp x-ui.service /etc/systemd/system/

    if [ -d bin ]; then
        cp bin/* /usr/local/x-ui/bin/ && chmod +x /usr/local/x-ui/bin/*
        # Xray软链
        ARCH=$(uname -m)
        if [[ $ARCH == "x86_64" ]]; then ln -sf /usr/local/x-ui/bin/xray-linux-64 /usr/local/x-ui/bin/xray; fi
        if [[ $ARCH == "aarch64" ]]; then ln -sf /usr/local/x-ui/bin/xray-linux-arm64 /usr/local/x-ui/bin/xray; fi
    fi

    # 下载geo文件
    cd /usr/local/x-ui/
    wget -O geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat >/dev/null 2>&1
    wget -O geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat >/dev/null 2>&1

    # 自动生成默认config.json允许IP访问
    cat > bin/config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": []
  },
  "policy": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 2,
        "downlinkOnly": 5,
        "statsUserUplink": true,
        "statsUserDownlink": true,
        "bufferSize": 10240
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  }
}
EOF
    cp bin/config.json /usr/local/x-ui/bin/config.json
    yellow "生成默认config.json (IP访问: 0.0.0.0:54321)"

    cd /tmp && rm -rf x-ui-src
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    sleep 3
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
        iptables-save > /etc/iptables.rules
    fi
    green "端口已放行。"
}

main() {
    export LANG=en_US.UTF-8
    echo -e "\n${green}安装自定义X-Panel v25.9.25...${yellow}"
    install_deps
    install_core
    firewall_setting
    IP=$(curl -s ipinfo.io/ip || echo "your-server-ip")
    echo -e "\n${green}成功！${yellow}"
    echo "地址: http://${IP}:54321/ (IP直连启用)"
    echo "用户名/密码: admin/admin (立即修改: x-ui user)"
    echo "状态: x-ui status"
    echo "日志: x-ui log"
    echo "警告: IP访问不安全，尽快加SSL (x-ui 选18)"
}

main "$@"