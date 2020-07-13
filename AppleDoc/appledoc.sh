#!/bin/bash

#注释不能在一条命令语句的换行内，不然会报错: 'command not found'

#文档输出目录
#忽略.m文件，因.m中均为私有api和属性，开源的接口文档中理应忽略掉
#工程的名字
#公司的名字
#不生成docset，直接输出html
#没有注释的文件也输出html  -->目的是看到所有的文件
#没有注释的属性和方法也输出到html  -->目的是看到所有的属性和方法
#没有注释的文件不提示警告
#没有注释的属性和方法不提示警告
#需要输出的文件路径  -->这里推荐最好直接为当前工程路径平级输出，便于维护和使用

appledoc \
--output ./AppleDoc \
-i *.m \
--project-name "TEST" \
--project-company "MTX Software Technology Co.,Ltd" \
--no-create-docset \
--keep-undocumented-objects \
--keep-undocumented-members \
--no-warn-undocumented-object \
--no-warn-undocumented-member \
./
