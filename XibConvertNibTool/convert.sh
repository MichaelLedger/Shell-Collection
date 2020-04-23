#!/bin/bash
pwd
# 将xib编译成nib文件
function transitionToNib(){
    ibtool --errors --warnings --output-format human-readable-text --compile ibtool --errors --warnings --output-format human-readable-text --compile $1 $2
}

#function deleteXib() {
#    find . -name ".xib" -print
#     find . -name ".xib" -exec rm -r {} \;
#}

#处理输入的参数 并编译成nib (/Users/zengchunjun/Desktop/selfStudy/xib-\>nib/TableViewCell.xib 分离出TableViewCell.xib 与 TableViewCell.nib)
function handlFile(){
    ORIGIN=$1
    echo "==handleFile:"$1"=="
    
    file=$1
    
#只处理xib后缀文件
#注意：
#1、提取文件后缀名： ${file##*.}其中##是贪婪操作符，从左至右匹配，匹配到最右边的.号，移除包含.号的左边内容。
#2、是=，而且其两边有空格，如果没有空格，会报错
#3、多加了x，是为了防止字符串为空时报错。
    if [ "${file##*.}"x != "xib"x ];then
        echo '==file is not xib:'$1'=='
        return
    fi

    XIBFILE=${ORIGIN##*/}
#    echo "$XIBFILE xib文件"

    FILENAME="${ORIGIN%.*}"
    NIBFILEDIR=$FILENAME".nib"
    NIBFILE=${NIBFILEDIR##*/}

#    echo "$FILENAME file名"
#    echo "$NIBFILE nib文件"

    transitionToNib $NIBFILE $XIBFILE
    
    # 移除xib文件
    rm $1
    echo "==deleteFile:"$1"=="
}

#循环目录，将每个xib编译成nib
function scandir() {
    local cur_dir parent_dir workdir
    workdir=$1
    cd ${workdir}
    if [ ${workdir} = "/" ]
    then
        cur_dir=""
    else
        cur_dir=$(pwd)
    fi

    for dirlist in $(ls ${cur_dir})
    do
        if test -d ${dirlist};then
            cd ${dirlist}
            scandir ${cur_dir}/${dirlist}
            cd ..
        else
#            echo "${cur_dir}/${dirlist} 子文件"

            handlFile ${cur_dir}/${dirlist}

        fi
    done
}


#判断是否有输入参数 需输入一个xib文件 或 一个只包含xib的文件 注意，xib文件名不能为空，否则不会被编译成nib
if [ ! -n "$1" ] ;then
    echo "you have not input a xibfile or directory of xibfile!"
    exit 1
else
    echo "the word you input is $1"
fi

#判断是文件还是文件夹
if test -d $1
then

    echo "you input a directory:'$1'"

    scandir $1

    exit 0

elif test -f $1
then
    echo "you input a xibfile:'$1'"

    handlFile $1
    
    exit 0
else
    echo "the Directory isn't exist which you input, pls input a new one!"
    exit 1
fi
