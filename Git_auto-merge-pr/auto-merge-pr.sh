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
# MERGE_BRANCH_PREFIX="username_merge"

GIT_REPO_DIR_MAIN="/Users/gavin/Downloads/freeprints_ios_3"
GIT_REPO_DIR_SDK="/Users/gavin/Downloads/freeprints_ios_3/FreePrints/MyDealsSDK"
MERGE_BRANCH_PREFIX="gavin_merge"

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
	MERGE_BRANCH_PREFIX="merge"
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
	merge_branch="${MERGE_BRANCH_PREFIX}_${source_branch}_to_${target_branch}"
	
	if [[ $merge_branch == *"master"* ]]
		then
			echo "target_branch contains master"
			merge_branch=${merge_branch//master/mst}
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


	# git merge origin/${source_branch} -m "Merge remote-tracking branch 'origin/${source_branch}' into ${target_branch}"
	# Use local branch to merge, do not need to push local feature branch to remote.
	git merge ${source_branch} -m "Merge remote-tracking branch '${source_branch}' into ${target_branch}"
	merge_result=$?
	if [ $merge_result == 0 ]
	then
		echo "merge success."
	else
		echo "merge failed: $merge_result, please resolve conflict manaully!!!"
		exit
	fi

	git push -u origin ${merge_branch}:${merge_branch}
	push_result=$?
	if [ $push_result == 0 ] 
	then
		echo "push success!"
		git switch $source_branch
		#remove local merge branch
		git branch -D ${merge_branch}
	fi

	#hub pull-request --base FP_3.13.0 --no-edit --head simon_fp_mydeals --reviewer Pingapplepie,JammyZ,hardawayye
	# hub pull-request --base FP_3.13.0 --no-edit --head simon_fp_mydeals --reviewer Pingapplepie,JammyZ,hardawayye
	hub pull-request --base $target_branch -m "merge $source_branch to $target_branch" --head $merge_branch

else
	echo "usage, first param is target project(main, sdk), second param is target branch, third param is source branch"
fi
