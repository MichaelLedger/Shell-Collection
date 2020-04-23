## 说明

**递归指定文件夹 `<dir-name>` 下所有的 `xib` 文件进行转 `nib` 操作**

###  使用场景
打包 SDK（静态库or动态库）时，`xib`不会被编译成 `nib`。
如果你直接在主项目中使用 `xib`，编译的时候就会把 `xib` 转换为 `nib`。
生成 SDK 则需要我们手动把 `xib `转换为 `nib`。
SDK（静态库 or 动态库）中建议使用 `bundle` 统一存放 `xib` 文件。

### 使用方法

#### 单个转换
终端执行如下命令：
```
$ sh convert.sh xxx.xib
```
或者
```
$ bash convert.sh xxx.xib
```

#### 批量转换
1. 将 `xib` 文件或包含 `xib` 文件的文件夹统一放在同一个目录 `<dir-name>` 下，不会对其他类型文件做任何处理。

2. 终端执行如下命令：
```
$ cd XibConvertNibTool
$ sh convert.sh <dir-name>
```
或者
```
$ cd XibConvertNibTool
$ bash convert.sh <dir-name>
```

3. 执行完毕后会删除所有的 `xib` 文件并在同级目录生成 `nib` 文件，大功告成~

### 终端报错解决
```
xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools'
```
解决该问题只需要设置xcode中的命令行工具：
`Xcode -> Xcode -> Preference.. -> Locations -> Command Line Tools` 
选择最新即可!

### 终端实例
*方式一*
```
$ ls
MediaPalyViewControllerFenDuan.xib    README.md                convert.sh
$ sh convert.sh MediaPalyViewControllerFenDuan.xib
/Users/mxr/Desktop/Shell-Collection-master/XibConvertNibTool
the word you input is MediaPalyViewControllerFenDuan.xib
you input a xibfile:'MediaPalyViewControllerFenDuan.xib'
==handleFile:MediaPalyViewControllerFenDuan.xib==
==deleteFile:MediaPalyViewControllerFenDuan.xib==
```

*方式二*
```
Last login: Sun Feb 23 12:50:05 on ttys002
MountainXs-MacBook-Pro:~ mountainx$ pwd
/Users/mountainx
MountainXs-MacBook-Pro:~ mountainx$ sh /Users/mountainx/MXR/MXRSDK/XibConvertNibTool/convert.sh xib
==before cd /Users/mountainx/MXR/MXRSDK/XibConvertNibTool==
/Users/mountainx
==after cd /Users/mountainx/MXR/MXRSDK/XibConvertNibTool==
/Users/mountainx/MXR/MXRSDK/XibConvertNibTool
the word you input is xib
you input  a directory
==handleFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView.xib==
==deleteFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView.xib==
==handleFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView_land.xib==
/* com.apple.ibtool.document.warnings */
/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView_land.xib:xZI-Eg-4Dj: warning: Automatically Adjusts Font requires using a Dynamic Type text style [9]
==deleteFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView_land.xib==
```

*方式三*
```
MountainXs-MacBook-Pro:~ mountainx$ pwd
/Users/mountainx
MountainXs-MacBook-Pro:~ mountainx$ cd /Users/mountainx/MXR/MXRSDK/XibConvertNibTool
MountainXs-MacBook-Pro:XibConvertNibTool mountainx$ pwd
/Users/mountainx/MXR/MXRSDK/XibConvertNibTool
MountainXs-MacBook-Pro:XibConvertNibTool mountainx$ ls
MXRBookUI.bundle    convert.sh        xib
README.md        original-xib
MountainXs-MacBook-Pro:XibConvertNibTool mountainx$ bash convert.sh xib
==before cd /Users/mountainx/MXR/MXRSDK/XibConvertNibTool==
/Users/mountainx/MXR/MXRSDK/XibConvertNibTool
==after cd /Users/mountainx/MXR/MXRSDK/XibConvertNibTool==
/Users/mountainx/MXR/MXRSDK/XibConvertNibTool
the word you input is xib
you input  a directory
==handleFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView.xib==
==deleteFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView.xib==
==handleFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView_land.xib==
/* com.apple.ibtool.document.warnings */
/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView_land.xib:xZI-Eg-4Dj: warning: Automatically Adjusts Font requires using a Dynamic Type text style [9]
==deleteFile:/Users/mountainx/MXR/MXRSDK/XibConvertNibTool/xib/MXRBookTopView_land.xib==
```
