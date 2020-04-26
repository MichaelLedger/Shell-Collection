# FFmpeg-commands

## 使用场景
ffmpeg 常用命令总结，譬如：AVI转MP4、MP4转TS、视频压缩、去除视频声音、合并音频和视频等等

## 终端命令

### 安装ffmpeg
`% brew install ffmpeg`

### 视频格式转换
#### AVI转MP4
`% ffmpeg -i xxx.avi xxx.mp4`
或者
`% sh translate.sh big_buck_bunny.avi output.mp4`
#### TS转MP4
`% ffmpeg -i xxx.ts xxx.mp4`
或者
`% sh translate.sh big_buck_bunny.ts output.mp4`
#### MP4转AVI
`% ffmpeg -i xxx.mp4 xxx.avi`
或者
`% sh translate.sh big_buck_bunny.mp4 output.avi`
#### MP4转TS
`% ffmpeg -i xxx.mp4 xxx.ts`
或者
`% sh translate.sh big_buck_bunny.mp4 output.ts`

### 视频压缩
#### 压缩帧率
`% ffmpeg –i input.mp4 –r <fps> output.mp4`
#### 压缩码率
音频：-b:a 视频： - b:v
`% ffmpeg -i input.avi -b:v 1500k output.mp4`
#### 压缩文件大小(播放时长)
-fs (file size首字母缩写)
`% ffmpeg -i input.avi -fs 1024K output.mp4`
**(视频码率+音频码率) * 时长 /8 = 输出文件大小K**
#### 压缩分辨率
`% ffmpeg -i input_file -s 320x240 output_file`

## FFmpeg 
### 主要组成部分
1、libavformat：用于各种音视频封装格式的生成和解析，包括获取解码所需信息以生成解码上下文结构和读取音视频帧等功能，包含demuxers和muxer库；
2、libavcodec：用于各种类型声音/图像编解码；
3、libavutil：包含一些公共的工具函数；
4、libswscale：用于视频场景比例缩放、色彩映射转换；
5、libpostproc：用于后期效果处理；
6、ffmpeg：是一个命令行工具，用来对视频文件转换格式，也支持对电视卡实时编码；
7、ffsever：是一个HTTP多媒体实时广播流服务器，支持时光平移；
8、ffplay：是一个简单的播放器，使用ffmpeg 库解析和解码，通过SDL显示；

### 基础概念
容器(Container)
容器就是一种文件格式，比如flv，mkv等。包含下面5种流以及文件头信息。
流(Stream)
是一种视频数据信息的传输方式，5种流：音频，视频，字幕，附件，数据。
帧(Frame)
帧代表一幅静止的图像，分为I帧，P帧，B帧。
编解码器(Codec)
是对视频进行压缩或者解压缩，CODEC =COde （编码） +DECode（解码）
复用/解复用(mux/demux)
把不同的流按照某种容器的规则放入容器，这种行为叫做复用（mux）
把不同的流从某种容器中解析出来，这种行为叫做解复用(demux)

### 处理流程
1、FFmpeg程序把-i参数指定的若干文件内容读入到内存，按照输入的参数或者程序默认的参数来处理并且把结果写入到若干的文件中。输入和输出文件可以是计算机文件、管道、网络流、捕获设备等。
2、FFmpeg用libavformat包调用解复用器（demuxers）来读取输入文件中被编码的数据包(packets)，如果有多个输入文件，FFmpeg以有效输入流的最小时间戳来同步，
3、然后解码器（decoder）从已编码的数据包中产生未被压缩的帧（frame），在那之后调用可选的过滤器。
4、这些帧被传递到编码器，编码器会产生新的编码包
5、把新的编码包传递给复用器(muxer)处理并且把结果写入到输出文件中。

### 过滤器（Filter）
在多媒体处理中，filter的意思是被编码到输出文件之前用来修改输入文件内容的一个软件工具。如：视频翻转，旋转，缩放等。
语法：[input_link_label1]… filter_name=parameters [output_link_label1]…
1、视频过滤器 -vf
如input.mp4视频按顺时针方向旋转90度
ffplay -i input.mp4 -vf transpose=1
如input.mp4视频水平翻转(左右翻转)
ffplay -i input.mp4 -vf hflip
2、音频过滤器 -af
实现慢速播放，声音速度是原始速度的50%
offplay input.mp3 -af atempo=0.5

过滤器链（Filterchain）
Filterchain = 逗号分隔的一组filter
语法：“filter1,filter2,filter3,…filterN-2,filterN-1,filterN”
顺时针旋转90度并水平翻转
ffplay -i input.mp4 -vf transpose=1,hflip

过滤器图(Filtergraph)
第一步： 源视频宽度扩大两倍。
ffmpeg -i jidu.mp4 -t 10 -vf pad=2*iw output.mp4
第二步：源视频水平翻转
ffmpeg -i jidu.mp4 -t 10 -vf hflip output2.mp4
第三步：水平翻转视频覆盖output.mp4
ffmpeg -i output.mp4 -i output2.mp4 -filter_complex overlay=w compare.mp4
是不是很复杂？
用带有链接标记的过滤器图(Filtergraph)只需一条命令

基本语法
Filtergraph = 分号分隔的一组filterchain
“filterchain1;filterchain2;…filterchainN-1;filterchainN”

Filtergraph的分类
1、简单(simple) 一对一
2、复杂(complex）多对一， 多对多

简单过滤器图处理流程：
simple:
decoded frames -> simple filter graph -> filtered frames -> encoder -> encoded data packets

复杂过滤器图处理流程：
complex:
input1                                                                                                                      output1
            -> decoded frames -> complex filter graph -> encoded data packets -> 
input2                                                                                                                      output2

可以发现复杂过滤器图比简单过滤器图少2个步骤，效率比简单高，ffmpeg建议尽量使用复杂过滤器图。
对于刚才用三步处理的方式，用过滤器图可以这样做：
ffplay -f lavfi -i testsrc -vf split[a][b];[a]pad=2*iw[1];[b]hflip[2];[1][2]overlay=w
F1: split过滤器创建两个输入文件的拷贝并标记为[a],[b]
F2: [a]作为pad过滤器的输入，pad过滤器产生2倍宽度并输出到[1].
F3: [b]作为hflip过滤器的输入，vflip过滤器水平翻转视频并输出到[2].
F4: 用overlay过滤器把 [2]覆盖到[1]的旁边.

### 选择媒体流
一些多媒体容器比如AVI，mkv，mp4等，可以包含不同种类的多个流，如何从容器中抽取各种流呢？
语法：
-map file_number[:stream_type][:stream_number]

这有一些特别流符号的说明：
1、-map 0 选择第一个文件的所有流
2、-map i:v 从文件序号i(index)中获取所有视频流， -map i:a 获取所有音频流，-map i:s 获取所有字幕流等等。
3、特殊参数-an,-vn,-sn分别排除所有的音频，视频，字幕流

假设有两个文件ffmpeg -i fist.mp4 -i second.mp4 ..output.mp4
如果想去两个文件的音视频流 ffmpeg -i fist.mp4 -i second.mp4 map:0 -map 1 output.mp4
如果想去第一个文件的视频流，第二个文件的音频流ffmpeg -i fist.mp4 -i second.mp4 -map:v:0 -map:a:0 output.mp4


### 查看帮助
可用的bit流 ：ffmpeg –bsfs
可用的编解码器：ffmpeg –codecs
可用的解码器：ffmpeg –decoders
可用的编码器：ffmpeg –encoders
可用的过滤器：ffmpeg –filters
可用的视频格式：ffmpeg –formats
可用的声道布局：ffmpeg –layouts
可用的license：ffmpeg –L
可用的像素格式：ffmpeg –pix_fmts
可用的协议：ffmpeg -protocals

### 码率、帧率和文件大小
码率和帧率是视频文件的最重要的基本特征，对于他们的特有设置会决定视频质量。如果我们知道码率和时长那么可以很容易计算出输出文件的大小。

帧率：帧率也叫帧频率，帧率是视频文件中每一秒的帧数，肉眼想看到连续移动图像至少需要15帧。
码率：比特率(也叫码率，数据率)是一个确定整体视频/音频质量的参数，秒为单位处理的字节数，码率和视频质量成正比，在视频文件中中比特率用bps来表达。

> 设置帧率
1、用 -r 参数设置帧率
ffmpeg –i input.mp4 –r fps output.mp4
2、用fps filter设置帧率
ffmpeg -i clip.mpg -vf fps=fps=25 clip.webm

> 设置码率 –b 参数
-b
ffmpeg -i film.avi -b 1.5M film.mp4
音频：-b:a 视频： - b:v
设置视频码率为1500kbps
ffmpeg -i input.avi -b:v 1500k output.mp4

> 控制输出文件大小
-fs (file size首字母缩写)
ffmpeg -i input.avi -fs 1024K output.mp4
计算输出文件大小
(视频码率+音频码率) * 时长 /8 = 文件大小K

### 调整视频分辨率

用-s参数设置视频分辨率，参数值wxh，w宽度单位是像素，h高度单位是像素
ffmpeg -i input_file -s 320x240 output_file

### 裁剪视频crop filter
从输入文件中选取你想要的矩形区域到输出文件中,常见用来去视频黑边。
语法：crop:ow[:oh[:x[:y:[:keep_aspect]]]]

裁剪输入视频的左三分之一，中间三分之一，右三分之一:
ffmpeg -i input -vf crop=iw/3:ih :0:0 output
ffmpeg -i input -vf crop=iw/3:ih :iw/3:0 output
ffmpeg -i input -vf crop=iw/3:ih :iw/3*2:0 output

裁剪帧的中心
当我们想裁剪区域在帧的中间时，裁剪filter可以跳过输入x和y值，他们的默认值是
Xdefault = ( input width - output width)/2
Ydefault = ( input height - output height)/2
ffmpeg -i input_file -v crop=w:h output_file
裁剪中间一半区域：
ffmpeg -i input.avi -vf crop=iw/2:ih/2 output.avi

比较裁剪后的视频和源视频比较
ffplay -i jidu.mp4 -vf split[a][b];[a]drawbox=x=(iw-300)/2:(ih-300)/2:w=300:h=300:c=yellow[A];[A]pad=2iw[C];[b]crop=300:300:(iw-300)/2:(ih-300)/2[B];[C][B]overlay=w2.4:40

自动检测裁剪区域
cropdetect filter 自动检测黑边区域
ffplay jidu.mp4 -vf cropdetect
然后用检测到的值来裁剪视频
ffplay jidu.mp4 –vf crop=672:272:0:54

填充视频(pad)
在视频帧上增加一快额外额区域，经常用在播放的时候显示不同的横纵比
语法：pad=width[:height:[:x[:y:[:color]]]]

创建一个30个像素的粉色宽度来包围一个SVGA尺寸的图片：
ffmpeg -i photo.jpg -vf pad=860:660:30:30:pink framed_photo.jpg

同理可以制作input.mp4视频用30个像素粉色包围视频
ffplay -i input.mp4 -vf pad=iw+60:ih+60:30:30:pink

4:3到16:9
一些设备只能播放16:9的横纵比，4:3的横纵比必须在水平方向的两边填充成16:9，
高度被保持，宽度等于高度乘以16/9，x（输入文件水平位移）值由表达式(output_width - input_width)/2来计算。

4：3到16:9的通用命令是：
ffmpeg -i input.mp4 -vf pad=ih16/9:ih :(ow-iw)/2:0:color output.mp4
eg:ffplay -f input.mp4 -vf pad=ih16/9:ih:(ow-iw)/2:0:pink

16:9到4:3
为了用4:3的横纵比来显示16:9的横纵比，填充输入文件的垂直两边，宽度保持不变，高度是宽度的3/4，y值（输入文件的垂直偏移量）是由一个表达式（output_height-input_height）/2计算出来的。

16:9到4:3的通用命令：
ffmpeg -i input.mp4-vf pad=iw :iw3/4:0:(oh-ih)/2:color output.mp4
eg:ffplay -i input.mp4 =size=320x180 -vf pad=iw:iw3/4:0:(oh-ih)/2:pink

### 翻转和旋转

水平翻转语法: -vf hflip
ffplay -f lavfi -i testsrc -vf hflip
垂直翻转语法：-vf vflip
ffplay -f lavfi -i testsrc -vf vflip

语法：transpose={0,1,2,3}
0:逆时针旋转90°然后垂直翻转
1:顺时针旋转90°
2:逆时针旋转90°
3:顺时针旋转90°然后水平翻转

### 模糊，锐化

模糊
语法：boxblur=luma_r:luma_p[:chroma_r:chram_p[:alpha_r:alpha_p]]
ffplay -f lavfi -i testsrc -vf boxblur=1:10:4:10
注意：luma_r和alpha_r半径取值范围是0~min(w,h)/2, chroma_r半径的取值范围是0~min(cw/ch)/2

锐化
语法：-vf unsharp=l_msize_x:l_msize_y:l_amount:c_msize_x:c_msize_y:c_amount
所有的参数是可选的，默认值是5:5:1.0:5:5:0.0
l_msize_x:水平亮度矩阵，取值范围3-13，默认值为5
l_msize_y:垂直亮度矩阵，取值范围3-13，默认值为5
l_amount:亮度强度，取值范围-2.0-5.0，负数为模糊效果，默认值1.0
c_msize_x:水平色彩矩阵，取值范围3-13，默认值5
c_msize_y:垂直色彩矩阵，取值范围3-13，默认值5
c_amount:色彩强度，取值范围-2.0-5.0，负数为模糊效果，默认值0.0
eg:
使用默认值，亮度矩阵为5x5和亮度值为1.0
ffmpeg -i input.mp4 -vf unsharp output.mp4
高斯模糊效果(比较强的模糊)：
ffplay -i input.mp4 -vf unsharp=13:13:-2

覆盖（画中画)

语法：overlay[=x[:y]
所有的参数都是可选，默认值都是0

Logo在左上角
ffmpeg -i input.mp4 -i logo.png -filter_complex overlay output.mp4
右上角：
ffmpeg -i input.mp4 -i logo.png -filter_complex overlay=W-w output.mp4
左下角：
ffmpeg -i input.mp4 -i logo.png -filter_complex overlay=0:H-h output.mp4
右下角：
ffmpeg -i input.mp4 -i logo.png -filter_complex overlay=W-w:H-h output.mp4

删除logo
语法：-vf delogo=x:y:w:h[:t[:show]]
x:y 离左上角的坐标
w:h logo的宽和高
t: 矩形边缘的厚度默认值4
show：若设置为1有一个绿色的矩形，默认值0.
ffplay -i jidu.mp4 -vf delogo=50:51:60:60:100:0

### 添加文本
语法：
drawtext=fontfile=font_f:text=text1[:p3=v3[:p4=v4[…]]]
常用的参数值
x：离左上角的横坐标
y: 离左上角的纵坐标
fontcolor：字体颜色
fontsize：字体大小
text:文本内容
textfile:文本文件
t：时间戳，单位秒
n:帧数开始位置为0
draw/enable:控制文件显示，若值为0不显示，1显示，可以使用函数

1、在左上角添加Welcome文字
ffplay -i color=c=white -vf drawtext=fontfile=arial.ttf:text=Welcom
2、在中央添加Good day
ffplay -i color=c=white -vf drawtext="fontfile=arial.ttf:text='Goodday':x=(w-tw)/2:y=(h-th)/2"
3、设置字体颜色和大小
ffplay -i color=c=white -vf drawtext="fontfile=arial.ttf:text='Happy Holidays':x=(w-tw)/2:y=(h-th)/2:fontcolor=green:fontsize=30"

动态文本
用 t (时间秒)变量实现动态文本
1、顶部水平滚动
ffplay -i jidu.mp4 -vf drawtext="fontfile=arial.ttf:text='Dynamic RTL text':x=w-t50:fontcolor=darkorange:fontsize=30"
2、底部水平滚动
ffplay -i jidu.mp4 -vf drawtext="fontfile=arial.ttf:textfile=textfile.txt:x=w-t50:y=h-th:fontcolor=darkorange:fontsize=30"
3、垂直从下往上滚动
ffplay jidu.mp4 -vf drawtext="textfile=textfile:fontfile=arial.ttf:x=(w-tw)/2:y=h-t*100:fontcolor=white:fontsize=30“
在右上角显示当前时间 localtime
ffplay jidu.mp4 -vf drawtext="fontfile=arial.ttf:x=w-tw:fontcolor=white:fontsize=30:text='%{localtime:%H\:%M\:%S}'“

每隔3秒显示一次当前时间
ffplay jidu.mp4 -vf drawtext="fontfile=arial.ttf:x=w-tw:fontcolor=white:fontsize=30:text='%{localtime:%H\:%M\:%S}':enable=lt(mod(t,3),1)"

### 图片支持
FFmpeg支持绝大多数图片处理, 除LJPEG（无损JPEG）之外，其他都能被解码，除了EXR,PIC,PTX之外，所有的都能被编码。
截取一张图片使用 –ss(seek from start)参数.
ffmpeg -ss 01:23:45 -i jidu.mp4 image.jpg
从视频中生成GIF图片
ffmpeg -i jidu.mp4 -t 10 -pix_fmt rgb24 jidu.gif
转换视频为图片（每帧一张图）
ffmpeg -i clip.avi frame%4d.jpg
图片转换为视频
ffmpeg -f image2 -i img%4d.jpg -r 25 video.mp4

### 裁剪、填充
和视频一样，图片也可以被裁剪和填充
裁剪
ffmpeg -f lavfi -i rgbtestsrc -vf crop=150:150 crop_rg.png
填充
ffmpeg -f lavfi -i smptebars -vf pad=360:280:20:20:orange pad_smpte.jpg

### 翻转，旋转，覆盖

和视频一样图片同样能翻转，旋转和覆盖
翻转
ffmpeg -i orange.jpg -vf hflip orange_hfilp.jpg
ffmpeg -i orange.jpg -vf vflip orange_vfilp.jpg
旋转
ffmpeg -i image.png -vf transpose=1 image_rotated.png
覆盖
ffmpeg -f lavfi -i rgbtestsrc -s 400x300 rgb .png
ffmpeg -f lavfi -i smptebars smpte.png
ffmpeg -i rgb .png -i smpte.png -filter_complex overlay= (W-w)/2:(H-h)/2 rgb_smpte.png

### 屏幕录像
显示设备名称
ffmpeg -list_devices 1 -f dshow -i dummy
调用摄像头
ffplay -f dshow -i video="Integrated Camera"
保存为文件
ffmpeg -y -f dshow -s 320x240 -r 25 -i video="Integrated Camera" -b:v 800K -vcodec mpeg4 new.mp4

### 添加字幕subtitles
语法 –vf subtitles=file
ffmpeg -i jidu.mp4 -vf subtitles=rgb.srt output.mp4

### 视频颤抖、色彩平衡 
视频颤抖
ffplay –i jidu.mp4 -vf crop=in_w/2:in_h/2:(in_w-out_w)/2+((in_w-out_w)/2)sin(n/10):(in_h-out_h)/2 +((in_h-out_h)/2)sin(n/7)

色彩平衡
ffplay -i jidu.mp4 -vf curves=vintage
色彩变幻
ffplay -i jidu.mp4 -vf hue="H=2PIt: s=sin(2PIt)+1“
彩色转换黑白
ffplay -i jidu.mp4 -vf lutyuv="u=128:v=128"

### 设置音频视频播放速度
3倍视频播放视频
ffplay -i jidu.mp4 -vf setpts=PTS/3
¾速度播放视频
ffplay -i jidu.mp4 -vf setpts=PTS/(3/4)
2倍速度播放音频
ffplay -i speech.mp3 -af atempo=2

### 截图
每隔一秒截一张图
ffmpeg -i input.flv -f image2 -vf fps=fps=1 out%d.png
每隔20秒截一张图
ffmpeg -i input.flv -f image2 -vf fps=fps=1/20 out%d.png

注意：ffmpeg version N-57961-gec8e68c版本最多可以每隔20s截一张图。
多张截图合并到一个文件里（2x3） 每隔一千帧(秒数=1000/fps25)即40s截一张图
ffmpeg -i jidu.mp4 -frames 3 -vf "select=not(mod(n,1000)),scale=320:240,tile=2x3" out.png

## 参考资料
![MAC 系统安装FFmpeg](https://www.jianshu.com/p/73441acf7815)
![ffmpeg 常用命令总结](https://blog.csdn.net/weixin_42081389/article/details/100543007)
![ffmpeg 基本用法](https://www.jianshu.com/p/3c8c4a892f3c)
