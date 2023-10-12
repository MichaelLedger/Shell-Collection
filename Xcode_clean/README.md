# clean.sh

## 使用场景
使用脚本快速清理 Xcode

## 使用说明
`Xcode` 会占用很大的内存空间
特别是各个版本的 `iOS` 的 `runtime` 文件
文件目录在 `~/Library/Developer/Xcode/iOS\ DeviceSupport`
这个根据个人手动筛选删除，建议每个大版本保留一个即可（**方便使用模拟器测试版本兼容问题**）
需要的小版本可以后续使用的时候下载
Xcode12以上可能存在一个问题，长期运行会一直占用越来越多的内存空间，甚至高达几十G，建议经常性地重启一下Xcode！

删除 `runtime` 并不会影响该版本的模拟器正常运行~

模拟器设备目录：
 `~/Library/Developer/CoreSimulator/Devices`
 这个根据个人手动筛选删除，也可以通过Xcode->Add Additional Simulators...->Simulators选择模拟器进行删除
 此目录占用的内存不大。
 建议配合同级目录下的另一个脚本 `Xcode-Simulator-Mapping` 获取模拟器的 runtime 和 device 的 mapping 表，便于精准删除不必要的模拟器。
 
 删除模拟器后运行该模拟器会报错，需要清除支持模拟器缓存~
 ```
 Unable to boot device because it cannot be located on disk.
 
 The device's data is no longer present at /Users/mxr/Library/Developer/CoreSimulator/Devices/6C43CAD1-218E-4630-8A88-B24AE45C0BCC/data.
 Use the device manager in Xcode or the simctl command line tool to either delete the device properly or erase contents and settings.
 ```

## 温馨提示
资源库 `/Users/user/Library` 下文件夹占用系统内存的绝大部分，多大情况可以达到100G以上！
建议手动进行删除无用的或者已卸载App的缓存文件，**切记不可全选删除**！
建议使用命令`$ ls -la` 或者  `$ ls -lhtr` 进行查看文件最近访问时间！
使用Finder排序文件大小进行判断是否需要删除，删除切记谨慎！！！

## 特别提醒
请勿在终端输入 `rm -rf ~` 会删除当前用户根目录下面的全部文件 ! ! !

# xclean.sh

## zsh script to clear xcode caches and project

## Works from Xcode 9.3 to Xcode 11.6

The script is pretty self explanatory. I made it to work with zsh (shell), if you want to use safely with other shell, you need to change the firstline of the script. But if you have zsh installed it should run just fine.

After that, just **make sure that you are indeed inside a folder which contains a workspace or a xcodeproject (or both)** and run the command

## Tips

Move this script to /usr/bin/local so this will be the default usage:
```
cd myXcodeWorkspace/
xclean
```

forked from [resetXcode.sh](https://gist.github.com/arthurdapaz/e2a4fc83fa561ec52af83a5b08d0497d)

refer from 

[Reset Xcode. Clean, clear module cache, Derived Data and Xcode Caches. You can thank me later.](https://gist.github.com/maciekish/66b6deaa7bc979d0a16c50784e16d697)

[Xcode: "is out of date and needs to be rebuilt"](https://discussions.apple.com/thread/254240507)


# uninstall-xcode.sh

Uninstall xcode completely from your mac

https://developer.apple.com/forums/thread/110227

Assuming you put Xcode in the Applications folder; to remove all traces of Xcode from your disk, remove:
```
/Applications/Xcode.app
~/Library/Caches/com.apple.dt.Xcode
~/Library/Developer
~/Library/MobileDevice
~/Library/Preferences/com.apple.dt.Xcode.plist
/Library/Preferences/com.apple.dt.Xcode.plist
/System/Library/Receipts/com.apple.pkg.XcodeExtensionSupport.bom
/System/Library/Receipts/com.apple.pkg.XcodeExtensionSupport.plist
/System/Library/Receipts/com.apple.pkg.XcodeSystemResources.bom
/System/Library/Receipts/com.apple.pkg.XcodeSystemResources.plist
```

To scavenge your customizations, first copy these somewhere safe (folder where noted, file where noted)
```
~/Library/Developer/Xcode/UserData/CodeSnippets
~/Library/Developer/Xcode/UserData/FontAndColorThemes
~/Library/Developer/Xcode/UserData/KeyBindings
~/Library/Developer/Xcode/Templates
~/Library/Preferences/com.apple.dt.Xcode.plist
~/Library/MobileDevice/Provisioning Profiles
```

Xcode has been exceptionally buggy since day 1 of it's existance... so it is good to know how to remove all of it for a re-install when your simulators don't install, when simulators are broken after install, when nothing will compile or run, when things run fine in the simulator but not on the iPhone or iPad hardware, etc.

(if I forgot some trace, apologies, please reply back to complete the list)
