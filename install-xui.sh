#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误: ${plain} 请使用 root 权限运行此脚本\n" && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo -e "${red}检查服务器操作系统失败，请联系作者!${plain}" >&2
    exit 1
fi

echo -e "——————————————————————"
echo -e "当前服务器的操作系统为:${red} $release${plain}"
echo ""
xui_version=$(/usr/local/x-ui/x-ui -v)
last_version=$(curl -Ls "https://api.github.com/repos/xeefei/x-panel/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo -e "${green}当前代理面板的版本为: ${red}〔X-Panel面板〕v${xui_version}${plain}"
echo ""
echo -e "${yellow}〔X-Panel面板〕最新版为---------->>> ${last_version}${plain}"

os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

if [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} 请使用 CentOS 8 或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${red} 请使用 Ubuntu 20 或更高版本!${plain}\n" && exit 1
    fi

elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red} 请使用 Fedora 36 或更高版本!${plain}\n" && exit 1
    fi

elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 11 ]]; then
        echo -e "${red} 请使用 Debian 11 或更高版本 ${plain}\n" && exit 1
    fi

elif [[ "${release}" == "almalinux" ]]; then
    if [[ ${os_version} -lt 9 ]]; then
        echo -e "${red} 请使用 AlmaLinux 9 或更高版本 ${plain}\n" && exit 1
    fi

elif [[ "${release}" == "rocky" ]]; then
    if [[ ${os_version} -lt 9 ]]; then
        echo -e "${red} 请使用 RockyLinux 9 或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "arch" ]]; then
    echo "您的操作系统是 ArchLinux"
elif [[ "${release}" == "manjaro" ]]; then
    echo "您的操作系统是 Manjaro"
elif [[ "${release}" == "armbian" ]]; then
    echo "您的操作系统是 Armbian"
elif [[ "${release}" == "alpine" ]]; then
    echo "您的操作系统是 Alpine Linux"
elif [[ "${release}" == "opensuse-tumbleweed" ]]; then
    echo "您的操作系统是 OpenSUSE Tumbleweed"
elif [[ "${release}" == "oracle" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} 请使用 Oracle Linux 8 或更高版本 ${plain}\n" && exit 1
    fi
else
    echo -e "${red}此脚本不支持您的操作系统。${plain}\n"
    echo "请确保您使用的是以下受支持的操作系统之一："
    echo "- Ubuntu 20.04+"
    echo "- Debian 11+"
    echo "- CentOS 8+"
    echo "- Fedora 36+"
    echo "- Arch Linux"
    echo "- Parch Linux"
    echo "- Manjaro"
    echo "- Armbian"
    echo "- Alpine Linux"
    echo "- AlmaLinux 9+"
    echo "- Rocky Linux 9+"
    echo "- Oracle Linux 8+"
    echo "- OpenSUSE Tumbleweed"
    exit 1

fi

# Declare Variables
log_folder="${XUI_LOG_FOLDER:=/var/log}"
iplimit_log_path="${log_folder}/3xipl.log"
iplimit_banned_log_path="${log_folder}/3xipl-banned.log"

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default $2]: " temp
        if [[ "${temp}" == "" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ "${temp}" == "y" || "${temp}" == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "重启面板，注意：重启面板也会重启 Xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按 Enter 键返回主菜单：${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/xeefei/x-panel/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "$(echo -e "${green}该功能将强制安装最新版本，并且数据不会丢失。${red}你想继续吗？${plain}---->>请输入")" "y"
    if [[ $? != 0 ]]; then
        LOGE "已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/xeefei/x-panel/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "更新完成，面板已自动重启"
        exit 0
    fi
}

update_menu() {
    echo -e "${yellow}更新菜单项${plain}"
    confirm "此功能会将所有菜单项更新为最新显示状态" "y"
    if [[ $? != 0 ]]; then
        LOGE "Cancelled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/xeefei/x-panel/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    
     if [[ $? == 0 ]]; then
        echo -e "${green}更新成功，面板已自动重启${plain}"
        exit 0
    else
        echo -e "${red}更新菜单项失败${plain}"
        return 1
    fi
}

custom_version() {
    echo "输入面板版本 (例: 2.3.8):"
    read panel_version

    if [ -z "$panel_version" ]; then
        echo "面板版本不能为空。"
        exit 1
    fi

    download_link="https://raw.githubusercontent.com/xeefei/x-panel/master/install.sh"

    # Use the entered panel version in the download link
    install_command="bash <(curl -Ls $download_link) v$panel_version"

    echo "下载并安装面板版本 $panel_version..."
    eval $install_command
}

# Function to handle the deletion of the script file
delete_script() {
    rm "$0"  # Remove the script file itself
    exit 1
}

uninstall() {
    confirm "您确定要卸载面板吗? Xray 也将被卸载!" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "卸载成功\n"
    echo "如果您需要再次安装此面板，可以使用以下命令:"
    echo -e "${green}bash <(curl -Ls https://raw.githubusercontent.com/xeefei/x-panel/master/install.sh)${plain}"
    echo ""
    # Trap the SIGTERM signal
    trap delete_script SIGTERM
    delete_script
}

reset_user() {
    confirm "您确定重置面板的用户名和密码吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    read -rp "请设置用户名 [默认为随机用户名]: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "请设置密码 [默认为随机密码]: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    /usr/local/x-ui/x-ui setting -remove_secret >/dev/null 2>&1
    echo -e "面板登录用户名已重置为：${green} ${config_account} ${plain}"
    echo -e "面板登录密码已重置为：${green} ${config_password} ${plain}"
    echo -e "${yellow} 面板 Secret Token 已禁用 ${plain}"
    echo -e "${green} 请使用新的登录用户名和密码访问 X-Panel 面板。也请记住它们！${plain}"
    confirm_restart
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length)
    echo $random_string
}

set_web_base_path() {
    echo -e "${yellow}修改访问路径${plain}"
    config_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath（访问路径）: .+' | awk '{print $2}') 
    read -p "请设置新的访问路径（若回车默认或输入y则为随机路径）: " new_path
    if [[ -z $new_path ]]; then
        if confirm "是否随机生成访问路径" "y"; then
            new_path="/$(gen_random_string 8)"
        else
            new_path=$config_webBasePath
        fi
    fi
    /usr/local/x-ui/x-ui setting -webBasePath $new_path >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        echo -e "面板访问路径已重置为: ${green}${new_path}${plain}"
        echo -e "${green}请使用新的路径登录访问面板${plain}"
    else
        echo -e "${red}设置访问路径失败${plain}"
    fi
    confirm_restart
}

reset_config() {
    confirm "您确定要重置所有面板设置，帐户数据不会丢失，用户名和密码不会更改" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "所有面板设置已重置为默认，请立即重新启动面板，并使用默认的${green}13688${plain}端口访问网页面板"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "获取当前设置错误，请检查日志"
        show_menu
    fi
    echo -e "${info}${plain}"
    echo ""
    
    # 获取 IPv4 和 IPv6 地址
    v4=$(curl -s4m8 http://ip.sb -k)
    v6=$(curl -s6m8 http://ip.sb -k)
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath（访问路径）: .+' | awk '{print $2}') 
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port（端口号）: .+' | awk '{print $2}') 
    local existing_cert=$(/usr/local/x-ui/x-ui setting -getCert true | grep -Eo 'cert: .+' | awk '{print $2}')
    local existing_key=$(/usr/local/x-ui/x-ui setting -getCert true | grep -Eo 'key: .+' | awk '{print $2}')

    if [[ -n "$existing_cert" && -n "$existing_key" ]]; then
        echo -e "${green}面板已安装证书采用SSL保护${plain}"
        echo ""
        local existing_cert=$(/usr/local/x-ui/x-ui setting -getCert true | grep -Eo 'cert: .+' | awk '{print $2}')
        domain=$(basename "$(dirname "$existing_cert")")
        echo -e "${green}登录访问面板URL: https://${domain}:${existing_port}${green}${existing_webBasePath}${plain}"
    fi
    echo ""
    if [[ -z "$existing_cert" && -z "$existing_key" ]]; then
        echo -e "${red}警告：未找到证书和密钥，面板不安全！${plain}"
        echo ""
        echo -e "${green}------->>>>请按照下述方法设置〔ssh转发〕<<<<-------${plain}"
        echo ""
        # 检查 IP 并输出相应的 SSH 和浏览器访问信息
        if [[ -n $v4 ]]; then
            echo -e "1、本地电脑客户端转发命令：${green}ssh -L 15208:127.0.0.1:${existing_port} root@${v4}${plain} 或者 ${green}ssh -L [::]:15208:127.0.0.1:${existing_port} root@[${v6:-v6}]${plain}"
        fi
        echo "2、请通过快捷键【Win + R】调出运行窗口，在里面输入【cmd】打开本地终端服务"
        echo "3、请在终端中成功输入服务器的〔root密码〕，注意区分大小写，用以上命令进行转发"
        echo "4、请在浏览器地址栏复制 ${green}127.0.0.1:15208/${existing_webBasePath}${plain} 或者 ${green}[::1]:15208/${existing_webBasePath}${plain} 进入〔X-Panel面板〕登录界面"
        echo ""
        echo -e "${yellow}注意：若不使用〔ssh转发〕请为X-Panel面板配置安装证书再行登录管理后台${plain}"
    fi

    echo -e "${yellow}--------------------------------------------------${plain}"
    echo -e "${yellow}>>>>>>>>注：若您安装了〔证书〕，请使用您的域名用https方式登录${plain}"
    echo -e "${yellow}--------------------------------------------------${plain}"
    echo ""
    echo -e "${yellow}请确保 ${existing_port} 端口已打开放行${plain}"
    echo -e "${yellow}请自行确保此端口没有被其他程序占用${plain}"
    echo ""
    echo -e "${yellow}--------------------------------------------------${plain}"
    before_show_menu
}

set_port() {
    echo -e "${yellow}设置端口${plain}"
    config_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port（端口号）: .+' | awk '{print $2}') 
    read -p "请输入端口号 (默认 ${config_port}): " new_port
    if [[ -z $new_port ]]; then
        new_port=$config_port
    fi

    old_port=$config_port  # 保存旧端口用于防火墙删除

    /usr/local/x-ui/x-ui setting -port $new_port >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        echo -e "端口已修改为 ${green}${new_port}${plain}"

        # 自动放行新端口
        if command -v ufw >/dev/null; then
            ufw delete allow $old_port/tcp || true
            ufw allow $new_port/tcp && ufw reload
            echo "ufw 已放行端口 $new_port"
        elif command -v firewall-cmd >/dev/null; then
            firewall-cmd --permanent --remove-port=$old_port/tcp || true
            firewall-cmd --permanent --add-port=$new_port/tcp && firewall-cmd --reload
            echo "firewalld 已放行端口 $new_port"
        else
            iptables -D INPUT -p tcp --dport $old_port -j ACCEPT || true
            iptables -I INPUT -p tcp --dport $new_port -j ACCEPT
            iptables-save > /etc/iptables.rules
            echo "iptables 已放行端口 $new_port"
        fi
    else
        echo -e "${red}设置端口失败${plain}"
    fi
    confirm_restart
}

start() {
    if [[ $# == 0 ]]; then
        confirm "确定启动面板?" "y"
    fi
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    systemctl start x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green} X-Panel 已成功启动 ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
    else
        echo -e "${red} X-Panel 启动失败，可能是启动时间超过两秒，请稍后查看日志信息 ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
    fi
}

stop() {
    if [[ $# == 0 ]]; then
        confirm "确定关闭面板?" "y"
    fi
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green} X-Panel 和 Xray 已成功关闭 ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
    else
        echo -e "${red} X-Panel 关闭失败 ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
    fi
}

restart() {
    if [[ $# == 0 ]]; then
        confirm "确定重启面板?" "y"
    fi
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    systemctl restart x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green} X-Panel 已成功重启 ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
    else
        echo -e "${red} X-Panel 重启失败，可能是启动时间超过两秒，请稍后查看日志信息 ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
    fi
}

status() {
    systemctl status x-ui --no-pager
}

log() {
    journalctl -xe -u x-ui --no-pager
}

enable() {
    systemctl enable x-ui
    echo -e "${green} X-Panel 已设置为开机启动 ${plain}"
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    echo -e "${green} X-Panel 已禁用开机启动 ${plain}"
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

ssl() {
    echo -e "${yellow}SSL 证书管理${plain}"
    cert_info=$(/usr/local/x-ui/x-ui setting -getCert true)
    if [[ $? != 0 ]]; then
        LOGE "获取证书信息错误，请检查日志"
        before_show_menu
    fi
    echo -e "${cert_info}${plain}"
    echo ""
    confirm "进入证书管理菜单" "y"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    echo -e "${yellow}1.${plain} 申请证书"
    echo -e "${yellow}2.${plain} 安装证书"
    echo -e "${yellow}3.${plain} 查看证书"
    echo -e "${yellow}4.${plain} 卸载证书"
    echo -e "${yellow}5.${plain} 返回主菜单"
    read -p "请输入选择 [1-5]: " num
    case "$num" in
    1)
        cert_domain
        ;;
    2)
        install_cert
        ;;
    3)
        view_cert
        ;;
    4)
        uninstall_cert
        ;;
    5)
        show_menu
        ;;
    *)
        LOGE "请输入正确的选择 [1-5]"
        ssl
        ;;
    esac
}

cert_domain() {
    echo -e "${yellow}申请证书${plain}"
    echo -e "${green}1.${plain} 使用Let's Encrypt申请证书"
    echo -e "${green}2.${plain} 使用Cloudflare申请证书"
    echo -e "${green}3.${plain} 返回主菜单"
    read -p "请输入选择 [1-3]: " num
    case "$num" in
    1)
        lets_encrypt
        ;;
    2)
        cloudflare
        ;;
    3)
        show_menu
        ;;
    *)
        LOGE "请输入正确的选择 [1-3]"
        cert_domain
        ;;
    esac
}

lets_encrypt() {
    echo -e "${yellow}Let's Encrypt申请证书${plain}"
    read -p "请输入域名: " domain
    if [[ -z $domain ]]; then
        LOGE "域名不能为空"
        lets_encrypt
    fi
    /usr/local/x-ui/x-ui setting -letsEncrypt $domain >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        LOGI "证书申请成功"
        confirm_restart
    else
        LOGE "证书申请失败，请检查日志"
        before_show_menu
    fi
}

cloudflare() {
    echo -e "${yellow}Cloudflare申请证书${plain}"
    read -p "请输入域名: " domain
    if [[ -z $domain ]]; then
        LOGE "域名不能为空"
        cloudflare
    fi
    read -p "请输入Cloudflare API Token: " token
    if [[ -z $token ]]; then
        LOGE "API Token不能为空"
        cloudflare
    fi
    /usr/local/x-ui/x-ui setting -cloudflare $domain $token >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        LOGI "证书申请成功"
        confirm_restart
    else
        LOGE "证书申请失败，请检查日志"
        before_show_menu
    fi
}

install_cert() {
    echo -e "${yellow}安装证书${plain}"
    read -p "请输入证书文件路径: " cert_file
    if [[ -z $cert_file ]]; then
        LOGE "证书文件路径不能为空"
        install_cert
    fi
    read -p "请输入私钥文件路径: " key_file
    if [[ -z $key_file ]]; then
        LOGE "私钥文件路径不能为空"
        install_cert
    fi
    /usr/local/x-ui/x-ui setting -cert $cert_file $key_file >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        LOGI "证书安装成功"
        confirm_restart
    else
        LOGE "证书安装失败，请检查日志"
        before_show_menu
    fi
}

view_cert() {
    echo -e "${yellow}查看证书${plain}"
    cert_info=$(/usr/local/x-ui/x-ui setting -getCert true)
    if [[ $? != 0 ]]; then
        LOGE "获取证书信息错误，请检查日志"
        before_show_menu
    fi
    echo -e "${cert_info}${plain}"
    before_show_menu
}

uninstall_cert() {
    confirm "您确定要卸载证书吗?" "n"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    /usr/local/x-ui/x-ui setting -remove_cert >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        LOGI "证书卸载成功"
        confirm_restart
    else
        LOGE "证书卸载失败，请检查日志"
        before_show_menu
    fi
}

iplimit() {
    echo -e "${yellow}IP 限制管理${plain}"
    echo -e "${green}1.${plain} 开启IP限制"
    echo -e "${green}2.${plain} 关闭IP限制"
    echo -e "${green}3.${plain} 查看IP限制日志"
    echo -e "${green}4.${plain} 清空IP限制日志"
    echo -e "${green}5.${plain} 返回主菜单"
    read -p "请输入选择 [1-5]: " num
    case "$num" in
    1)
        iplimit_enable
        ;;
    2)
        iplimit_disable
        ;;
    3)
        iplimit_log
        ;;
    4)
        iplimit_clear_log
        ;;
    5)
        show_menu
        ;;
    *)
        LOGE "请输入正确的选择 [1-5]"
        iplimit
        ;;
    esac
}

iplimit_enable() {
    echo -e "${yellow}开启IP限制${plain}"
    read -p "请输入IP限制次数: " limit
    if [[ -z $limit ]]; then
        LOGE "次数不能为空"
        iplimit_enable
    fi
    read -p "请输入IP限制时间 (分钟): " time
    if [[ -z $time ]]; then
        LOGE "时间不能为空"
        iplimit_enable
    fi
    /usr/local/x-ui/x-ui setting -iplimit $limit $time >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        LOGI "IP限制开启成功"
        confirm_restart
    else
        LOGE "IP限制开启失败，请检查日志"
        before_show_menu
    fi
}

iplimit_disable() {
    confirm "您确定要关闭IP限制吗?" "n"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    /usr/local/x-ui/x-ui setting -remove_iplimit >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        LOGI "IP限制关闭成功"
        confirm_restart
    else
        LOGE "IP限制关闭失败，请检查日志"
        before_show_menu
    fi
}

iplimit_log() {
    echo -e "${yellow}IP限制日志${plain}"
    tail -f $iplimit_log_path
}

iplimit_clear_log() {
    confirm "您确定要清空IP限制日志吗?" "n"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    > $iplimit_log_path
    > $iplimit_banned_log_path
    LOGI "IP限制日志已清空"
    before_show_menu
}

firewall() {
    echo -e "${yellow}防火墙管理${plain}"
    echo -e "${green}1.${plain} 开启防火墙"
    echo -e "${green}2.${plain} 关闭防火墙"
    echo -e "${green}3.${plain} 查看防火墙状态"
    echo -e "${green}4.${plain} 返回主菜单"
    read -p "请输入选择 [1-4]: " num
    case "$num" in
    1)
        firewall_enable
        ;;
    2)
        firewall_disable
        ;;
    3)
        firewall_status
        ;;
    4)
        show_menu
        ;;
    *)
        LOGE "请输入正确的选择 [1-4]"
        firewall
        ;;
    esac
}

firewall_enable() {
    if command -v ufw >/dev/null; then
        ufw enable
        LOGI "防火墙已开启"
    elif command -v firewall-cmd >/dev/null; then
        systemctl start firewalld
        systemctl enable firewalld
        LOGI "防火墙已开启"
    else
        LOGE "不支持的防火墙"
    fi
    before_show_menu
}

firewall_disable() {
    if command -v ufw >/dev/null; then
        ufw disable
        LOGI "防火墙已关闭"
    elif command -v firewall-cmd >/dev/null; then
        systemctl stop firewalld
        systemctl disable firewalld
        LOGI "防火墙已关闭"
    else
        LOGE "不支持的防火墙"
    fi
    before_show_menu
}

firewall_status() {
    if command -v ufw >/dev/null; then
        ufw status
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --list-all
    else
        LOGE "不支持的防火墙"
    fi
    before_show_menu
}

bbr() {
    echo -e "${yellow}启用 BBR ${plain}"
    confirm "确定启用 BBR 加速?" "y"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    wget --no-check-certificate -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    before_show_menu
}

update_geo() {
    echo -e "${yellow}更新 Geo 文件${plain}"
    confirm "确定更新 Geo 文件?" "y"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    /usr/local/x-ui/x-ui updateGeo >/dev/null 2>&1
    if [[ $? == 0 ]]; then
        LOGI "Geo 文件更新成功"
    else
        LOGE "Geo 文件更新失败，请检查日志"
    fi
    before_show_menu
}

speedtest() {
    echo -e "${yellow}Speedtest by Ookla${plain}"
    confirm "确定运行 Speedtest?" "y"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    wget --no-check-certificate -O speedtest.tar.gz https://install.speedtest.net/app/cli/ookla-speedtest-1.16.1.0-linux-x86_64.tgz
    tar -xzf speedtest.tar.gz
    ./ookla-speedtest --format=csv --accept-license
    rm -rf speedtest.tar.gz ookla-speedtest*
    before_show_menu
}

subscription() {
    echo -e "${yellow}安装订阅转换${plain}"
    confirm "确定安装订阅转换?" "y"
    if [[ $? != 0 ]]; then
        before_show_menu
    fi
    wget --no-check-certificate -O /usr/local/bin/sub && chmod +x /usr/local/bin/sub https://raw.githubusercontent.com/tindy2013/subconverter/master/subconverter.sh
    if [[ $? == 0 ]]; then
        LOGI "订阅转换安装成功"
        echo -e "使用: sub [选项] [配置文件] [订阅链接]"
    else
        LOGE "订阅转换安装失败"
    fi
    before_show_menu
}

show_menu() {
    echo -e "
——————————————————————
 ${green}  X-Panel 面板管理脚本 ${plain}
    一个更好的面板
   基于Xray Core构建
——————————————————————
 ${green} 0.${plain} 退出脚本
 ${green} 1.${plain} 安装面板
 ${green} 2.${plain} 更新面板
 ${green} 3.${plain} 更新菜单项
 ${green} 4.${plain} 自定义版本
 ${green} 5.${plain} 卸载面板
——————————————————————
 ${green} 6.${plain} 重置用户名、密码
 ${green} 7.${plain} 修改访问路径
 ${green} 8.${plain} 重置面板设置
 ${green} 9.${plain} 修改面板端口
 ${green} 10.${plain} 查看面板设置
——————————————————————
 ${green} 11.${plain} 启动面板
 ${green} 12.${plain} 关闭面板
 ${green} 13.${plain} 重启面板
 ${green} 14.${plain} 检查面板状态
 ${green} 15.${plain} 检查面板日志
——————————————————————
 ${green} 16.${plain} 启用开机启动
 ${green} 17.${plain} 禁用开机启动
——————————————————————
 ${green} 18.${plain} SSL 证书管理
 ${green} 19.${plain} CF SSL 证书
 ${green} 20.${plain} IP 限制管理
 ${green} 21.${plain} 防火墙管理
——————————————————————
 ${green} 22.${plain} 启用 BBR
 ${green} 23.${plain} 更新 Geo 文件
 ${green} 24.${plain} Speedtest by Ookla
 ${green} 25.${plain} 安装订阅转换
——————————————————————

面板状态: ${status}
开机启动: ${autostart}
Xray状态: ${xray_status}
请输入选项 [0-25]: "
    read -p "请输入选项 [0-25]: " num
    case "$num" in
    0)
        LOGI "退出脚本，拜拜"
        exit 0
        ;;
    1)
        install
        ;;
    2)
        update
        ;;
    3)
        update_menu
        ;;
    4)
        custom_version
        ;;
    5)
        uninstall
        ;;
    6)
        reset_user
        ;;
    7)
        set_web_base_path
        ;;
    8)
        reset_config
        ;;
    9)
        set_port
        ;;
    10)
        check_config
        ;;
    11)
        start
        ;;
    12)
        stop
        ;;
    13)
        restart
        ;;
    14)
        status
        ;;
    15)
        log
        ;;
    16)
        enable
        ;;
    17)
        disable
        ;;
    18)
        ssl
        ;;
    19)
        cert_domain
        ;;
    20)
        iplimit
        ;;
    21)
        firewall
        ;;
    22)
        bbr
        ;;
    23)
        update_geo
        ;;
    24)
        speedtest
        ;;
    25)
        subscription
        ;;
    *)
        LOGE "请输入正确的选择 [0-25]"
        show_menu
        ;;
    esac
}

# 启动脚本
main() {
    echo -e "——————————————————————
 ${green}  X-Panel 面板管理脚本 ${plain}
    一个更好的面板
   基于Xray Core构建
——————————————————————
 ${green} 0.${plain} 退出脚本
 ${green} 1.${plain} 安装面板
 ${green} 2.${plain} 更新面板
 ${green} 3.${plain} 更新菜单项
 ${green} 4.${plain} 自定义版本
 ${green} 5.${plain} 卸载面板
——————————————————————
 ${green} 6.${plain} 重置用户名、密码
 ${green} 7.${plain} 修改访问路径
 ${green} 8.${plain} 重置面板设置
 ${green} 9.${plain} 修改面板端口
 ${green} 10.${plain} 查看面板设置
——————————————————————
 ${green} 11.${plain} 启动面板
 ${green} 12.${plain} 关闭面板
 ${green} 13.${plain} 重启面板
 ${green} 14.${plain} 检查面板状态
 ${green} 15.${plain} 检查面板日志
——————————————————————
 ${green} 16.${plain} 启用开机启动
 ${green} 17.${plain} 禁用开机启动
——————————————————————
 ${green} 18.${plain} SSL 证书管理
 ${green} 19.${plain} CF SSL 证书
 ${green} 20.${plain} IP 限制管理
 ${green} 21.${plain} 防火墙管理
——————————————————————
 ${green} 22.${plain} 启用 BBR
 ${green} 23.${plain} 更新 Geo 文件
 ${green} 24.${plain} Speedtest by Ookla
 ${green} 25.${plain} 安装订阅转换
——————————————————————
 
----------------------------------------------
"
    read -p "请输入选项 [0-25]: " num
    case "$num" in
    0)
        LOGI "退出脚本，拜拜"
        exit 0
        ;;
    1)
        install
        ;;
    2)
        update
        ;;
    3)
        update_menu
        ;;
    4)
        custom_version
        ;;
    5)
        uninstall
        ;;
    6)
        reset_user
        ;;
    7)
        set_web_base_path
        ;;
    8)
        reset_config
        ;;
    9)
        set_port
        ;;
    10)
        check_config
        ;;
    11)
        start
        ;;
    12)
        stop
        ;;
    13)
        restart
        ;;
    14)
        status
        ;;
    15)
        log
        ;;
    16)
        enable
        ;;
    17)
        disable
        ;;
    18)
        ssl
        ;;
    19)
        cert_domain
        ;;
    20)
        iplimit
        ;;
    21)
        firewall
        ;;
    22)
        bbr
        ;;
    23)
        update_geo
        ;;
    24)
        speedtest
        ;;
    25)
        subscription
        ;;
    *)
        LOGE "请输入正确的选择 [0-25]"
        main
        ;;
    esac
}

# 启动脚本
main