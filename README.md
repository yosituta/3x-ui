## 重新安装
方式一：
bash <(curl -Ls https://raw.githubusercontent.com/yosituta/3x-ui/main/install.sh)

方式二：[下载后运行（更稳）]
rm -f install.sh && wget https://raw.githubusercontent.com/yosituta/3x-ui/main/install.sh && chmod +x install.sh && bash install.sh

## 彻底卸载/删除当前 3x-ui
如果你还能进入 x-ui 菜单（面板状态运行中）：
输入命令：Bashx-ui
选择 5 （卸载面板）
确认卸载（会自动停止服务、删除文件、删除 systemd 服务等）
卸载完成后，额外手动清理残留（防止万一）：
rm -rf /usr/local/x-ui/
rm -f /usr/bin/x-ui
rm -rf /root/.acme.sh/  # 如果你之前手动装过 acme.sh，可删可不删，不影响
systemctl stop x-ui 2>/dev/null
systemctl disable x-ui 2>/dev/null
rm -f /etc/systemd/system/x-ui.service
systemctl daemon-reload

## 如果 x-ui 菜单进不去，或卸载失败，直接手动删除（强制清理）：
systemctl stop x-ui 2>/dev/null
systemctl disable x-ui 2>/dev/null

## 删除所有相关文件和目录
rm -rf /usr/local/x-ui/
rm -f /usr/bin/x-ui
rm -f /etc/systemd/system/x-ui.service
systemctl daemon-reload
systemctl reset-failed  # 清理失败状态

# 可选：删除 acme.sh（如果你不想保留）
rm -rf /root/.acme.sh/

清理完成后，重启服务器更保险（可选）：
reboot

## xray启动不了的解决方式
在终端直接运行以下命令（一步步复制执行）：
# 1. 先停止服务，防止反复重启占用资源
systemctl stop x-ui

# 2. 清除错误的证书路径配置（关键一步！）
/usr/local/x-ui/x-ui setting -certFile "" -keyFile ""

# 或者用这个命令直接禁用 TLS（效果一样）
# /usr/local/x-ui/x-ui setting -tls false

# 3. 重启服务
systemctl restart x-ui

# 4. 检查服务状态
systemctl status x-ui

执行完第 4 步，你应该看到类似：
x-ui.service - x-ui Service
   Active: active (running)

验证是否成功
  输入 x-ui 进入菜单
  选 14 检查面板状态
  现在应该显示：
  面板状态: 运行中
  开机启动: 是
  Xray状态: 未运行   ← 这还是正常的！因为你还没添加节点
