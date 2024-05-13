#!bash

function split() {
	echo -e "\\n"

}

if [ `command -v hub` ]; then
    echo "hub installed"
else
    echo "hub not installed"
    brew install hub
fi

#The directory of the repository, please set below Environment variable before use this script
# GIT_REPO_DIR_MAIN="/path/to/main/project/repository"
# GIT_REPO_DIR_SDK="/path/to/sdk/repository"
# MERGE_BRANCH_PREFIX="username-merge"

MERGE_TICKET="FPA-000"
MERGE_AUTHOR="Gavin"
GIT_REPO_DIR_MAIN="/Users/gavinxiang/Downloads/freeprints_ios_3"
GIT_REPO_DIR_SDK="/Users/gavinxiang/Downloads/MyDealsSDK"
MERGE_BRANCH_PREFIX="${MERGE_TICKET}-${MERGE_AUTHOR}-Merge"

if [ -z "$GIT_REPO_DIR_MAIN" ]; then
	echo "please set GIT_REPO_DIR_MAIN environment variable"
	exit -1
fi
if [ -z "$GIT_REPO_DIR_SDK" ]; then
	echo "please set GIT_REPO_DIR_SDK environment variable"
	exit -1
fi
if [ -z "$MERGE_BRANCH_PREFIX" ]; then
	echo "Warning: please set MERGE_BRANCH_PREFIX environment variable"
	MERGE_BRANCH_PREFIX="Merge"
fi


if [ $# == 3 ]
then
	target_project=$1
	echo $1
	repo_dir=$GIT_REPO_DIR_MAIN
	if [[ $target_project == "main" ]]
	then
		echo "target_project is main"
		repo_dir=$GIT_REPO_DIR_MAIN
	elif [[ $target_project == "sdk" ]]
	then
		unset repo_dir
		repo_dir=$GIT_REPO_DIR_SDK
		echo "target_project is sdk"
	else
		echo "please set project type"
		exit
	fi

	split
	echo "$repo_dir"
	cd "$repo_dir"
	git fetch
	# pwd

	target_branch=$2
	source_branch=$3
	merge_branch="${MERGE_BRANCH_PREFIX}-${source_branch}-into-${target_branch}"
	
    # replace 'master' with 'Master' for merge branch name
	if [[ $merge_branch == *"master"* ]]
		then
			echo "target_branch contains master"
			merge_branch=${merge_branch//master/Master}
			echo "merge branch = $merge_branch"
	fi

	echo "target branch name = $target_branch, source branch name = $source_branch"
	
	split

	#remove exists remote merge_branch
	git ls-remote --exit-code --heads origin ${merge_branch}
	if [ $? == 0 ]
	then
		echo "remove remote ${merge_branch} now..."
		git push -d origin $merge_branch
	fi

	git show-ref --verify --quiet refs/heads/${merge_branch}
	if [ $? != 0 ]; then
		echo "merge branch does not exist, create it now..."
		git checkout -b $merge_branch origin/${target_branch}
		if [ $? == 0 ]; then
			echo "create merge branch success"
		else
			echo "create merge branch failed"
			exit 1
		fi
	else
		echo "branch already exists"
		git checkout $merge_branch
	fi

	split

    # NOTE: always using origin branch to merge!!!
    git merge origin/${source_branch} -m "Merge remote-tracking branch 'origin/${source_branch}' into ${target_branch}"
	# Use local branch to merge, do not need to push local feature branch to remote.
	# git merge ${source_branch} -m "Merge remote-tracking branch '${source_branch}' into ${target_branch}"
	merge_result=$?
	if [ $merge_result == 0 ]
	then
		echo "merge success."
	else
		echo "merge failed: $merge_result, please resolve conflict manaully, git merge --continue, then run it agagin!👮👮👮⚠️⚠️⚠️"
		exit
	fi

	git push -u origin ${merge_branch}:${merge_branch}
	push_result=$?
	if [ $push_result == 0 ]
	then
		echo "push success!"
    else
        echo "push failed: $push_result"
        exit
	fi

	#hub pull-request --base FP_3.13.0 --no-edit --head simon_fp_mydeals --reviewer Pingapplepie,JammyZ,hardawayye
    
    #NOTE: can't review my own pull request
    #--reviewer GavinXiangPlanetArt
    #Error requesting reviewer: Unprocessable Entity (HTTP 422)
    #Review cannot be requested from pull request author.
	hub pull-request --base $target_branch -m "Merge remote-tracking branch 'origin/${source_branch}' into ${target_branch}" --head $merge_branch
 
    pr_result=$?
    if [ $pr_result == 0 ]
    then
        echo "pull-request generate success! 🍺🍺🍺🎉🎉🎉"
        git switch $source_branch
        echo "switched to branch: $source_branch"
        #remove local merge branch
        git branch -D ${merge_branch}
    else
        echo "pull-request generate failed ❌❌❌😢😢😢: $pr_result"
        exit
    fi

else
	echo "Usage, first param is target project(main, sdk), second param is target branch, third param is source branch"
fi
