#!/bin/bash

# 避免删除其他路径下的文件！！！
echo "==before cd /Users/mxr/Desktop/XibConvertNibTool=="
pwd
cd /Users/mxr/Desktop/XibConvertNibTool
echo "==after cd /Users/mxr/Desktop/XibConvertNibTool=="
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
    return
else
    echo "the word you input is $1"
fi



#判断是文件还是文件夹
if test -d $1
then

    echo "you input  a directory"

    scandir $1

    exit 1

elif test -f $1
then
    echo "you input a xibfile "

    handlFile $1
    
    exit 1
else
    echo "the Directory isn't exist which you input,pls input a new one!!"
    exit 1
fi
