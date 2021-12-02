# Git_lines

## 使用场景
使用脚本快速根据日期统计研发人员的代码行数并导出为csv文件

## 使用注意
`git log --author` 需要替换为代码提交者的名称：`$ git config user.name`

## 终端实例
```
# 切换到Git项目目录下
$ cd ~/Desktop/repo_name
# 执行脚本
% sh ~/Downloads/Shell-Collection/Git_lines/git_lines.sh 2020 6 22 2021 12 2
[repo_name]-开始统计2020年6月22日至2021年12月2日每个人的代码行数...
结束统计:)
旧版本的Excel不支持逗号分割符
推荐使用Mac自带的Numbers打开《[repo_name]-2020年6月22日至2021年12月2日开发行数统计.csv》
```


