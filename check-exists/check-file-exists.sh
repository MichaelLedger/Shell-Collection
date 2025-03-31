#!/bin/bash
if [ ! $# == 1 ] ;then
    echo "--- please input your file's full path or relative path as the first param ---"
    exit
fi
file_path=$1
echo "Determining whether a file exists in Bash..."
#echo $1
#echo $file_path
if [ -f $file_path ]; then
  echo "[FILE] $file_path exists. 🎉"
else
  echo "[FILE] $file_path not exists! ❌"
fi
