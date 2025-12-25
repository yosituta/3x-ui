cat > install-fixed.sh << 'EOF'
#!/bin/bash

# ==========================================================
# 3x-UI Old Free Version One-Click Install Script (yosituta/3x-ui main, amd64 only)
# Usage: bash install-fixed.sh
# ==========================================================

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Please run as root (sudo bash install-fixed.sh)${plain}\n" && exit 1

# ----------------------------------------------------------
# OS and Arch Check (amd64 only)
# ----------------------------------------------------------
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo -e "${red}Unsupported OS${plain}" && exit 1
fi

arch() {
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        * ) echo -e "${red}Only Linux amd64 supported!${plain}" && exit 1 ;;
    esac
}

if [[ $(arch) != "amd64" ]]; then
    echo -e "${red}Error: This version only supports amd64. Use x86_64 server.${plain}"
    exit 1
fi

os_version=$(grep -i version_id /etc/os-release | cut -d '"' -f2 | cut -d . -f1)
if [[ "${release}" == "ubuntu" && ${os_version} -lt 20 ]] || [[ "${release}" == "debian" && ${os_version} -lt 11 ]] || [[ "${release}" == "centos" && ${os_version} -lt 8 ]]; then
    echo -e "${red}OS version too low, please upgrade.${plain}" && exit 1
fi

# ----------------------------------------------------------
# Install Base Dependencies
# ----------------------------------------------------------
install_base() {
    case "${release}" in
        ubuntu | debian)
            apt-get update && apt-get install -y wget curl tar tzdata
            ;;
        centos | rhel)
            yum update -y && yum install -y wget curl tar tzdata
            ;;
        *)
            echo -e "${red}Unsupported OS: $release${plain}" && exit 1
            ;;
    esac
}

# ----------------------------------------------------------
# Generate Random Credentials
# ----------------------------------------------------------
gen_random_string() {
    LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "${1:-16}" | head -n 1
}

# ----------------------------------------------------------
# Install Logic
# ----------------------------------------------------------
install_3xui() {
    echo -e "${green}Installing 3x-UI Old Free Version (amd64 only, no updates)${plain}"
    repo_url="https://raw.githubusercontent.com/yosituta/3x-ui/main"

    install_base

    cd /usr/local/
    # Stop and remove old version
    systemctl stop x-ui 2>/dev/null || true
    rm -rf x-ui

    # Download files
    echo -e "${green}Downloading components...${plain}"
    wget -N --no-check-certificate "${repo_url}/x-ui.sh" -O /usr/bin/x-ui && chmod +x /usr/bin/x-ui
    wget -N --no-check-certificate "${repo_url}/x-ui" -O x-ui && chmod +x x-ui
    wget -N --no-check-certificate "${repo_url}/x-ui.service" -O x-ui.service

    mkdir -p x-ui/bin
    cd x-ui
    wget -N --no-check-certificate "${repo_url}/bin/xray-linux-amd64" -O bin/xray-linux-amd64 && chmod +x bin/xray-linux-amd64
    wget -N --no-check-certificate "${repo_url}/bin/geoip.dat" -O bin/geoip.dat || true
    wget -N --no-check-certificate "${repo_url}/bin/geosite.dat" -O bin/geosite.dat || true

    # systemd service
    cp ../x-ui.service /etc/systemd/system/
    cat > /etc/systemd/system/x-ui.service << 'SERVICE_EOF'
[Unit]
Description=3x-UI
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
[Install]
WantedBy=multi-user.target
SERVICE_EOF

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    # Set random default credentials
    username=$(gen_random_string 8)
    password=$(gen_random_string 12)
    /usr/local/x-ui/x-ui setting -username "${username}" -password "${password}" -port 54321

    echo -e "${green}Installation complete!${plain}"
    echo -e "Panel URL: http://$(curl -s ifconfig.me):54321"
    echo -e "Username: ${username}"
    echo -e "Password: ${password}"
    echo -e "${yellow}Change credentials immediately! Command: x-ui setting${plain}"
    echo -e "${blue}Management: x-ui start/stop/restart/status${plain}"
}

# Run
install_3xui
EOF
chmod +x install-fixed.sh