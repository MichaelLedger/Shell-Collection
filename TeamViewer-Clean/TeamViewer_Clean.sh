#!/bin/bash

# 卸载后修改mac地址
# $ openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | xargs sudo ifconfig en0 ether
# 查看mac地址
# $ ifconfig en0 | grep ether
# 如果发现网络有不正常，则断开wifi再重新连接即可
# mac地址在电脑重启会变回原来的地址，所以重启后需要继续通过上述步骤进行设置。

# $ sudo find / -name *teamviewer*
sudo rm -rf /Library/Preferences/com.teamviewer.teamviewer.preferences.plist
sudo rm -rf /Library/PrivilegedHelperTools/com.teamviewer.Helper
sudo rm -rf /Library/LaunchAgents/com.teamviewer.teamviewer_desktop.plist
sudo rm -rf /Library/LaunchAgents/com.teamviewer.teamviewer.plist
sudo rm -rf /Library/LaunchDaemons/com.teamviewer.Helper.plist
sudo rm -rf /Library/LaunchDaemons/com.teamviewer.teamviewer_service.plist
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerAgent.bom
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerPriviledgedHelper.plist
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewer.plist
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerRestarter.plist
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewer.bom
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerPriviledgedHelper.bom
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerAuthPlugin.bom
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerAgent.plist
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerRestarter.bom
sudo rm -rf /private/var/db/receipts/com.teamviewer.teamviewerAuthPlugin.plist

# Dr.Cleaner Pathes
# Binary File
sudo rm -rf /Applications/TeamViewer.app
# Preferences
sudo rm -rf /Library/Preferences/com.teamviewer.TeamViewer.plist
sudo rm -rf /Library/Preferences/com.teamviewer.teamviewer.preferences.plist
sudo rm -rf /Library/Preferences/com.teamviewer.teamviewer.preferences.Machine.plist
# Supports
sudo rm -rf /Library/Application\ Support/TeamViewer
sudo rm -rf /Library/Caches/com.teamviewer.TeamViewer
sudo rm -rf /Library/Saved\ Application\ State/com.teamviewer.TeamViewer.savedState
