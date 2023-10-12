#!/bin/bash
# https://www.codegrepper.com/code-examples/shell
echo "Killing xcode..."
# kill $(ps aux | grep 'Xcode' | awk '{print $2}')
processname='Xcode'
PROCESS=`ps -ef|grep $processname|grep -v grep|grep -v PPID|awk '{ print $2}'`
for i in $PROCESS
   do
   echo "Kill the $1 process [ $i ]"
   kill -9 $i
done
# manual delete device support version in '~/Library/Developer/Xcode/iOS\ DeviceSupport'
# https://developer.apple.com/forums/thread/110227
echo "Remove all traces of Xcode"
sudo rm -rf ~/Library/Caches/com.apple.dt.Xcode
sudo rm -rf ~/Library/Developer
sudo rm -rf ~/Library/MobileDevice
sudo rm -rf ~/Library/Preferences/com.apple.dt.Xcode.plist
sudo rm -rf ~/Library/Preferences/com.apple.dt.Xcode.plist
sudo rm -rf /System/Library/Receipts/com.apple.pkg.XcodeExtensionSupport.bom
sudo rm -rf /System/Library/Receipts/com.apple.pkg.XcodeExtensionSupport.plist
sudo rm -rf /System/Library/Receipts/com.apple.pkg.XcodeSystemResources.bom
sudo rm -rf /System/Library/Receipts/com.apple.pkg.XcodeSystemResources.plist
