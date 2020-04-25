#!/bin/bash -ilex
if [ $# -ne 2 ]; then
    echo "two argument is needed, like this: % sh translate.sh xxx.avi xxx.mp4"
    # 'exit 1' means failed!
    exit 1
fi

if [ `command -v ffmpeg` ]; then
    echo "ffmpeg installed"
else
    echo "ffmpeg not installed"
    brew install ffmpeg
fi
ffmpeg -version

ffmpeg -i $1 $2

exit 0
