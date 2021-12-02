#!/bin/bash

if [ $# -ne 6 ]; then
    echo "six argument is needed, like this: $ sh git_lines.sh 2018 6 1 2018 6 30"
    # 'exit 1' means failed!
    exit 1
fi

# project_path=$(cd `dirname $0`; pwd)
# project_name="${project_path##*/}"

# echo $project_path
# echo $project_name

# work_path=$(dirname $0)
# echo ${work_path} 
pwd_path=$(pwd) 
# echo ${pwd_path}
pwd_name="${pwd_path##*/}"

csv=./[$pwd_name]-$1年$2月$3日至$4年$5月$6日开发行数统计_temp.csv

csv2=./[$pwd_name]-$1年$2月$3日至$4年$5月$6日开发行数统计.csv

echo "[$pwd_name]-开始统计$1年$2月$3日至$4年$5月$6日每个人的代码行数..."

# 移除同名文件

rm -rf $csv $csv2

# 防止csv乱码

# printf "\xEF\xBB\xBF" > $csv

echo "$1年$2月$3日至$4年$5月$6日的开发行数,,,," >> $csv

echo "开发人员,增加行数,删除行数,差值,合计" >> $csv

# 第一项($1)为增加的代码行数 第二项($2)为删除的代码行数 ($3)第三项为代码所在路径

# git log --author={正则表达式是此过滤器的基础机制}

git log --author=JayJiang --pretty=tformat: --numstat --since=$1-$2-$3 --until=$4-$5-$6 | awk '{add+=$1;del+=$2;diff+=$1-$2;total+=$1+$2}END{print "JayJiang,"add,",",del,",",diff,",",total}' >> $csv

git log --author=Mike --pretty=tformat: --numstat --since=$1-$2-$3 --until=$4-$5-$6 | awk '{add+=$1;del+=$2;diff+=$1-$2;total+=$1+$2}END{print "Mike,"add,",",del,",",diff,",",total}' >> $csv

git log --author=LaurenceFan --pretty=tformat: --numstat --since=$1-$2-$3 --until=$4-$5-$6 | awk '{add+=$1;del+=$2;diff+=$1-$2;total+=$1+$2}END{print "Laurence,"add,",",del,",",diff,",",total}' >> $csv

git log --author=kellyxu8 --pretty=tformat: --numstat --since=$1-$2-$3 --until=$4-$5-$6 | awk '{add+=$1;del+=$2;diff+=$1-$2;total+=$1+$2}END{print "Kelly,"add,",",del,",",diff,",",total}' >> $csv

git log --author="\(Watson\ Wang\)\|\(watsonPlanetart\)" --pretty=tformat: --numstat --since=$1-$2-$3 --until=$4-$5-$6 | awk '{add+=$1;del+=$2;diff+=$1-$2;total+=$1+$2}END{print "Watson,"add,",",del,",",diff,",",total}' >> $csv

git log --author=samuelc --pretty=tformat: --numstat --since=$1-$2-$3 --until=$4-$5-$6 | awk '{add+=$1;del+=$2;diff+=$1-$2;total+=$1+$2}END{print "Samuel,"add,",",del,",",diff,",",total}' >> $csv

git log --author=GavinXiang --pretty=tformat: --numstat --since=$1-$2-$3 --until=$4-$5-$6 | awk '{add+=$1;del+=$2;diff+=$1-$2;total+=$1+$2}END{print "Gavin,"add,",",del,",",diff,",",total}' >> $csv

# iconv文件字符转码为GB18030以支持Excel,避免中文乱码

iconv -f UTF8 -t GB18030 $csv >$csv2

# 移除UTF8编码的csv文件

rm -rf $csv

echo "结束统计:)"

echo "旧版本的Excel不支持逗号分割符"

echo "推荐使用Mac自带的Numbers打开《[$pwd_name]-$1年$2月$3日至$4年$5月$6日开发行数统计.csv》"

# 使用Mac自带的Numbers打开csv文件

open $csv2 -a Numbers
