#!/bin/bash

# run shell methods
# ./fir-upload.sh <ipa-path>
# sh fir-upload.sh <ipa-path>

# if run shell error: permission denied
# chmod +x fir-upload.sh
# chmod 755 fir-upload.sh
# sudo chmod -R 777 fir-upload.sh

# if you fetch SyntaxError while run fir-cli commands
# gem uninstall fir-cli
# rvm reinstall ruby-2.4.0

function exit_script() {
    exit 1
}

function install_fir_cli() {
    # check current version of fir-cli
    ruby -v
    # list known ruby versions
    rvm list known
    # firim bundler requires Ruby version >= 2.3.0.
    # rvm install 2.3.0
    # signet requires Ruby version >= 2.4.0.
    rvm install 2.4.0
    # firim bundler requires RubyGems version >= 2.5.2.
    gem update --system
    # install firim from ![](https://github.com/whlsxl/firim)
    # gem install firim
    # install fir-cli from ![](https://github.com/FIRHQ/fir-cli)
    gem install fir-cli
    # check current version of fir-cli
    fir -v
    # login fir with token from https://www.betaqr.com/apps
    fir login 246afdd2f1277fa519a467c6c1cbb1d3
    # look over current fir user info
    fir me
}

function publish_ipa() {
    # upload ipa to fir.im
    echo "publishing ipa to fir.im: $1..."
    fir publish $1
}

if [ `command -v fir` ]; then
    echo "fir-cli installed, start to publish ipa..."
else
    echo "fir-cli not installed, start to install fir-cli..."
    install_fir_cli
fi

# fir build ipa功能已过期, 请及时迁移打包部分, 推荐使用 fastlane gym 生成ipa 后再使用 fir-cli 上传
# fir build_ipa path/to/workspace -w -S /Users/mxr/Desktop/<Project-Root-Dir>

#参数处理    说明
#$#    传递到脚本或函数的参数个数
#$*    以一个单字符串显示所有向脚本传递的参数
#$$    脚本运行的当前进程ID号
#$!    后台运行的最后一个进程的ID号
#$@    与$*相同，但是使用时加引号，并在引号中返回每个参数。
#$-    显示Shell使用的当前选项，与set命令功能相同。
#$?    显示最后命令的退出状态。0表示没有错误，其他任何值表明有错误。
if [ $# -ne 1 ]; then
    echo "only one argument is needed for ipa path."
    exit_script
fi

echo $1
if [ X$1 = X ]
    then
        echo "the first argument is empty, please enter ipa path and rerun."
    else
        echo "the first argument is $1"
        publish_ipa $1
fi

# linux 命令中，如果命令执行成功，则 $?值为 0，否则不为 0.
# -eq 等于
# -ne 不等于
# -gt 大于
# -lt 小于
# -ge 大于等于
# -le 小于等于
if [ $? -ne 0 ]; then
    echo "====publish ipa failed: $1===="
else
    echo "====publish ipa success: $1===="
fi

exit_script
