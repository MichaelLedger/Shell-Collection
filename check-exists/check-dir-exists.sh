#!/bin/bash
if [ ! $# == 1 ] ;then
    echo "--- please input your directory's full path or relative path as the first param ---"
    exit
fi
dir_path=$1
echo "Determining whether a directory exists in Bash..."
#echo $1
#echo $dir_path
if [ -d $dir_path ]; then
  echo "[DIR] $dir_path exists. 🎉"
else
  echo "[DIR] $dir_path not exists! ❌"
fi
