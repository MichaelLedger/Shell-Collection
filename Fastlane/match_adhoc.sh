#!/bin/bash
 
function executeCommand() {
    cmd=$1
    echo -e "\033[41;37m Executing 【 $cmd 】. \033[0m"
    { 
        eval $cmd 
    } || { 
        echo -e "\033[41;37m Execute 【 $cmd 】 fail. \033[0m"
        exit 
    }
}
executeCommand "bundle exec fastlane ios match_adhoc readonly:false --env sti --verbose"
osascript -e 'display notification "" with title "Match succeesed!"'
