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
echo "Delete diretory from Library/Developer"
sudo rm -rf ~/Library/Developer/Xcode/Archives
sudo rm -rf ~/Library/Developer/Xcode/DerivedData
sudo rm -rf ~/Library/Developer/Xcode/iOS\ Device\ Logs
sudo rm -rf ~/Library/Developer/Xcode/Products
sudo rm -rf ~/Library/Developer/CoreSimulator/Devices 
