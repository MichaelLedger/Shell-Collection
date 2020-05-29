# Xcode_clean

## 使用场景
使用脚本快速清理 Xcode

## 使用说明
`Xcode` 会占用很大的内存空间
特别是各个版本的 `iOS` 的 `runtime` 文件
文件目录在 `~/Library/Developer/Xcode/iOS\ DeviceSupport`
这个根据个人手动筛选删除，建议每个大版本保留一个即可（**方便使用模拟器测试版本兼容问题**）
需要的小版本可以后续使用的时候下载

删除 `runtime` 并不会影响该版本的模拟器正常运行~

模拟器设备目录：
 `~/Library/Developer/CoreSimulator/Devices`
 这个根据个人手动筛选删除，也可以通过Xcode->Add Additional Simulators...->Simulators选择模拟器进行删除
 
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
