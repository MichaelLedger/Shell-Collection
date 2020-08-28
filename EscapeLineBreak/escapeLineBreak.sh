#!/bin/bash

#cat words.txt | sed 's/,/\n/g'|awk '{{printf"%s\\n",$0}}'

#escape1=`cat words.txt | sed 's/,/\n/g'|awk '{{printf"%s\\n",$0}}'`
#echo $escape1
#echo "$escape1" > escaped.txt

#cat words.txt | sed 's/,/\n/g'|tr -s '\n' '\\n'

#制表符：\n 换行符：\t
cat words.txt | sed 's/\\n/\n/g'|awk '{{printf"%s\\n",$0}}' > escaped.txt
temp=`cat escaped.txt`
#temp=`echo $temp`
echo "===tentative==="
echo $temp
#如果有多个换行，重复多次
cat escaped.txt | sed 's/\\n\\n\\n/\\n/g' > temp-1.txt
cat temp-1.txt | sed 's/\\n\\n/\\n/g' > temp-2.txt
cat temp-2.txt > escaped.txt
#删除临时文件
rm temp-1.txt
rm temp-2.txt

#doubleLineBreak="\n"

#grep判断
#$( echo $temp | grep "${doubleLineBreak}")
#字符串运算符 =~
#`[[ $temp =~ $doubleLineBreak ]]`
#正则表达式中的通配符 *
#`[[ $temp == *$doubleLineBreak* ]]`
#if [[ $temp == *$doubleLineBreak* ]];then
#echo "===contains==="
#cat escaped.txt | sed 's/\\n\\n\\n/\\n/g' > temp.txt
#cat escaped.txt | sed 's/\\n\\n/\\n/g' > temp.txt
#cat temp.txt > escaped.txt
#temp=`cat escaped.txt`
#    temp=`echo $temp`
#echo $temp
#else
#echo "===not contains==="
#fi
#


#contains=0
#while [[ contains != 0 ]]
#do
#    echo '==escapeing=='
#    #必须用另一个文件进行接受，否则文件内容会丢失！！！
#    cat escaped.txt | sed 's/\\n\\n/\\n/g' > temp.txt
#    cat temp.txt > escaped.txt
#    temp=`cat escaped.txt`
##    temp=`echo $temp`
#    echo $temp
#
#    if [[ $temp == *$doubleLineBreak* ]];then
#    echo "===contains==="
#    contains=1
#    else
#    echo "===not contains==="
#    contains=0
#    fi
#done

#echo "===result==="
#echo `cat escaped.txt`

#change multi-lines to one line methods
#cat words.txt
#a=`cat words.txt`;echo $a

#exchange line break to spacing
#tr -s "\n" " " < words.txt;echo







