*Inspired from [iOS Application Security]

## Usage
```
% cd Downloads/Shell-Collection/Xcode-Simulator-Mapping
% sh simulator.sh 
====start====
identifier : 40EE272A-16FF-4FCE-A634-508F35D2B701/
device : iPad Pro (11-inch) (3rd generation)
runtime : iOS_15.0
----------------------------------------------------------------
identifier : 7AD092C1-6E74-4E7B-A6C9-5A652825093D/
device : iPad Pro (12.9-inch) (5th generation)
runtime : iOS_15.0
----------------------------------------------------------------
identifier : 9DC20A8B-A13B-4BD5-8691-A61558DEEBF4/
device : iPhone 13
runtime : iOS_15.0
----------------------------------------------------------------
identifier : BACCDA07-4389-4A0C-A9E0-1E292A085119/
device : iPad Pro (9.7-inch)
runtime : iOS_15.0
----------------------------------------------------------------
identifier : CF8156A4-9274-4C11-926D-F781F80FB713/
device : iPhone 6
runtime : iOS_11.4
----------------------------------------------------------------
====done!====
```

## Device Directories
Starting with iOS 8, Simulator platforms such as iPhone, iPad, and their variations are stored in directories named with unique identifiers. These identifiers correspond with the type of device you choose when launching the Simulator from Xcode, in combination with the requested OS version. Each of these directories has a plist file that describes the device. Here’s an example:

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UDID</key>
    <string>7AD092C1-6E74-4E7B-A6C9-5A652825093D</string>
    <key>deviceType</key>
    <string>com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-5th-generation</string>
    <key>isDeleted</key>
    <false/>
    <key>isEphemeral</key>
    <false/>
    <key>name</key>
    <string>iPad Pro (12.9-inch) (5th generation)</string>
    <key>runtime</key>
    <string>com.apple.CoreSimulator.SimRuntime.iOS-15-0</string>
    <key>runtimePolicy</key>
    <string>Latest</string>
    <key>state</key>
    <integer>1</integer>
</dict>
</plist>

In this plist file, it’s not immediately obvious which directory is for which device. To figure that out, either you can look at the .default_created.plist
file in the Devices directory, or you can just grep all of the device.plist files, as shown in Listing

% cd ~/Library/Developer/CoreSimulator/Devices && ls

40EE272A-16FF-4FCE-A634-508F35D2B701    BACCDA07-4389-4A0C-A9E0-1E292A085119
7AD092C1-6E74-4E7B-A6C9-5A652825093D    CF8156A4-9274-4C11-926D-F781F80FB713
9DC20A8B-A13B-4BD5-8691-A61558DEEBF4    device_set.plist

```
# list all
for dir in `ls|grep -v default`

# list none directory
for dir in `ls -F | grep -v /$`

# list diretory
for dir in `ls -F | grep /$`
```

$ for dir in `ls|grep -v default`
do
echo $dir
grep -C1 name $dir/device.plist |tail -1|sed -e 's/<\/*string>//g' done

26E45178-F483-4CDD-A619-9C0780293DD4 iPhone 5s
676931A8-FDA5-4BDC-85CC-FB9E1B5368B6 iPhone 5
78CAAF2B-4C54-4519-A888-0DB84A883723 iPad Air
989328FA-57FA-430C-A71E-BE0ACF278786 iPhone 4s
A2CD467D-E110-4E38-A4D9-5C082618604A iPad Retina
AA9B1492-ADFE-4375-98F1-7DB53FF1EC44 Resizable iPad
AD45A031-2412-4E83-9613-8944F8BFCE42 Resizable iPhone
DF15DA82-1B06-422F-860D-84DCB6165D3C iPad 2
*Listing 3-1: Grepping to determine which identifier maps to which model of iOS device*

After entering the appropriate directory for the device you’ve been testing your application on, you’ll see a data directory that contains all of the Simulator files, including those specific to your application. Your application data is split into three main directories under data/Containers: Bundle, Data, and Shared.

## shell脚本里使用echo输出颜色
格式: `echo -e "\033[字背景颜色;字体颜色m字符串\033[0m"`

转义序列
```
要是通过彩色化提示符来增加个性化，就要用到转义序列。
转义序列就是一个让 shell 执行一个特殊步骤的控制指令。
转义序列通常都是以 ESC 开头（这也是它的命名原因）。 
在 shell 里表示为 ^[。
这种表示法需要一点时间去适应 也可以用 \033 完成相同的工作（ESC 的 ASCII 码用十进制表示就是 27， = 用八进制表示的 33）
转义字符用、“\e”.也就是说上面的\033、\e是相同的意思。
```

例如: 
`echo -e "\033[43;35m Hellow world ! \033[0m"`

其中43的位置代表底色, 35的位置是代表字的颜色

*Linux Terminal Color Codes*

字颜色:30~37
30:黑 black
31:红 red
32:绿 green
33:黄 yellow
34:蓝 blue
35:紫红 magenta
36:青 cyan
37:白 white

字背景颜色范围:40~47
40:黑 black
41:红 red
42:绿 green
43:黄 yellow
44:蓝 blue
45:紫红 magenta
46:青 cyan
47:白 white

ANSI控制码的说明
```
\33[0m 关闭所有属性 
\33[1m 设置高亮度 
\33[4m 下划线 
\33[5m 闪烁 
\33[7m 反显 
\33[8m 消隐 
\33[30m -- \33[37m 设置前景色 
\33[40m -- \33[47m 设置背景色 
\33[nA 光标上移n行 
\33[nB 光标下移n行 
\33[nC 光标右移n行 
\33[nD 光标左移n行 
\33[y;xH设置光标位置 
\33[2J 清屏 
\33[K 清除从光标到行尾的内容 
\33[s 保存光标位置 
\33[u 恢复光标位置 
\33[?25l 隐藏光标 
\33[?25h 显示光标
```
