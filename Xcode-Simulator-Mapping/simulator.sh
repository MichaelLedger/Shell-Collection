#!/bin/bash
#spin='-\|/'
prefix="Grepping to determine which identifier maps to which model of iOS device"
spin[0]=""
spin[1]="."
spin[2]=".."
spin[3]="..."
count=${#spin[@]}
j=0
#printf 'Please enter a positive integer number: ' || exit
#IFS= read -r number || [ -n "$number" ] || exit
#i=0; while [ "$i" -le "$number" ]; do
i=0; while [ "$i" -le 12 ]; do
#  printf '%s\n' "$i" || exit
# \33[2K erases the entire line your cursor is currently on
# \033[A moves your cursor up one line, but in the same column i.e. not to the start of the line
# \r (carriage return) brings your cursor to the beginning of the line (r is for carriage return N.B. carriage returns do not include a newline so cursor remains on the same line) but does not erase anything
#  printf "\r${spin:$j:1}"
  msg="\033[32m${prefix}${spin[j]}\033[0m"
  printf "\33[2K\r${msg}"
  sleep .5
  i=$((i + 1))
  j=$(((j+1) % count ))
done
printf "\33[2K\r"
cd ~/Library/Developer/CoreSimulator/Devices
for dir in `ls -F | grep /$`
do
DIRNAME=`echo ${dir} | sed -e 's/[/]*$//g'`
echo "identifier: \033[35m${DIRNAME}\033[0m"
DEVICE=`grep -w -C1 name $dir/device.plist |tail -1|sed -e 's/<\/*string>//g'`
#Trimming the leading and trailing spaces
DEVICENAME=`echo ${DEVICE} | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'`
echo "device: \033[32m${DEVICENAME}\033[0m"
#echo "\033[47;32m$DEVICENAME\033[0m"
RUNTIME=`grep -w -A1 runtime $dir/device.plist |tail -1|sed -e 's/<\/*string>//g'`
#Trimming the leading and trailing spaces
FULLRUNTIME=`echo ${RUNTIME} | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'`
SHORTRUNTIME=${FULLRUNTIME##*SimRuntime.}
REPLACED=${SHORTRUNTIME/-/ }
REPLACED=${REPLACED//-/.}
echo 'runtime:' "\033[40;36m$REPLACED\033[0m"
done
echo '====['$'\360\237\215\274'$'\360\237\215\270'$'\360\237\215\271'$'\360\237\215\273'$'\xF0\x9F\x8D\xBA' 'done!'']===='
exit 0
