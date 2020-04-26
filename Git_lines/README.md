# Git_lines

## 使用场景
使用脚本快速根据日期统计研发人员的代码行数并导出为csv文件

## 使用注意
`git log --author` 需要替换为代码提交者的名称：`$ git config user.name`

## 终端实例
```
# 切换到Git项目目录下
$ cd /Users/mxr/Desktop/4dbookcity
# 执行脚本
$ sh /Users/mxr/Desktop/XDS/git_lines.sh 2018 6 1 2018 6 30
开始统计2018年6月1日至2018年6月30日每个人的代码行数...
结束统计:)
旧版本的Excel不支持逗号分割符
推荐使用Mac自带的Numbers打开《2018年6月1日至2018年6月30日开发行数统计.csv》
```


