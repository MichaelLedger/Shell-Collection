# AppIcon-generator

## 使用步骤
准备一张需要处理的AppIcon图片，要求：

尺寸：1024*1024 (或者 width=height,width>=1024,height>=1024)

**透明通道：无**

**现在IOS图标是不需要再画圆角了，直接方形就OK**

名称：`1024.png` 

存放地址： `icon_gen.sh` 同级目录下

终端执行：
```
% cd AppIcon-generator
% sh icon_gen.sh
```

## 图标的圆角半径是多少？

括弧里面是对应的半径大小

App store(Retina屏) ─────────────1024px（160px）

iTunes Artwork icon ─────────────512px (90px)

App icon(iPhone4s) ──────────────────114px (20px)

App icon(iPhone5s) ──────────────────120px(22px)

App icon(iPad) ────────────────────72px (12px)

App icon(iPhone 3G/3GS) ───────────────57px(10px)

Spotlight/Settings icon icon(iPhone4) ──────────58px (10px)

Spotlight/Settings icon icon(iPhone 3G/3GS/iPad) ──── 29px (9px)


