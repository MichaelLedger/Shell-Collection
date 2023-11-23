# Clean App Extension Cache

## 使用场景
Xcode集成改脚本，编译时自动清理旧的AppExtension的cache缓存文件，避免不同target的extension编译文件被打包后导致安装包无法安装。

## 使用说明
如果工程中包含Embed Extension
譬如：
```
com.apple.background-asset-downloader-extension
com.apple.usernotifications.service
com.apple.widgetkit-extension
```
需要在脚本中自行添加对应Extension文件名称的匹配规则及相应文件路径。

将文件存储到项目脚本专属文件夹目录下后，配置script脚本在Xcode编译之前执行 `check-extensions.sh` 即可。

## Xcode配置
Target -> Build Phases -> New Run Script Phase -> 输入脚本内容
```
# Type a script or drag a script file from your workspace to insert its path.
/bin/sh "/${PROJECT_DIR}/scripts/check-extensions.sh"
```
将Run Script执行步骤置于Compile Sources之前。



