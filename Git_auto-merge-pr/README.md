# cmd_script - Auto merge branch and pull request
Some script for command line to improve productivity.

**NOTE: push local commits before auto-merge,shell always merge branches from remote-tracking!**
**NOTE: If conflicts exist, resolve it, git merge --continue, then run shell again to create pull-request from current merge-branch.**

```
# Merge remote-tracking branch 'origin/master' into 'origin/MD_3.67.0'
$ sh /Users/gavinxiang/Downloads/Shell-Collection/Git_auto-merge-pr/auto-merge-pr.sh sdk MD_3.67.0 master
```

## Command Alias Usage

**Cmd Alias Usage**
```
# Merge remote-tracking branch 'origin/master' into 'origin/MD_3.67.0'
$ am sdk MD_3.67.0 master
```

[Bash Scripting – Working of Alias](https://www.geeksforgeeks.org/bash-scripting-working-of-alias/)

[How to Add an Alias in macOS with Terminal](https://presscargo.io/articles/how-to-add-an-alias-in-macos-with-terminal/)

### Environment configurations
Edit `.bash_profile` by using cmds likes `nano .bash_profile' or `vim .bash_profile`.

```
➜  ~ cat .bash_profile  
export SYSTEM_VERSION_COMPAT=0

alias ..='cd ..'

alias ...='cd ../../'

alias l='ls -lah'

alias md='x'
x(){
    mkdir $1
    cd $1
}

alias am='automerge'
automerge(){
    sh /Users/gavinxiang/Downloads/Shell-Collection/Git_auto-merge-pr/auto-merge-pr.sh $1 $2 $3
}

[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/gavinxiang/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
```

### Refresh Custom Alias
To test your alias, type the following to refresh the shell environment:

`source ~/.bash_profile`

or

`source ~/.zshrc`

Or, you can just quit Terminal and start it up again.

**Git Cmd Alias Usage**
```
➜  ~ cat .gitconfig
[core]
    excludesfile = /Users/gavinxiang/.gitignore_global
[difftool "sourcetree"]
    cmd = opendiff \"$LOCAL\" \"$REMOTE\"
    path = 
[mergetool "sourcetree"]
    cmd = /Applications/Sourcetree.app/Contents/Resources/opendiff-w.sh \"$LOCAL\" \"$REMOTE\" -ancestor \"$BASE\" -merge \"$MERGED\"
    trustExitCode = true
[filter "lfs"]
    required = true
    clean = git-lfs clean -- %f
    smudge = git-lfs smudge -- %f
    process = git-lfs filter-process
[alias]           
    co=checkout           
    ci=commit           
    st=status           
    pl=pull           
    ps=push           
    dt=difftool
    mt=mergetool           
    l=log—stat           
    cp=cherry-pick           
    ca=commit-a           
    b=branch
    sm=submodule
[user]
    name = GavinXiang
    email = gavin.xiang@planetart.cn
[merge]
    tool = opendiff
[diff]
    tool = opendiff
[difftool]
    prompt = false
[pull]
    rebase = false
[commit]
    template = /Users/gavinxiang/.stCommitMsg
```

### Shell Preparation:

Environment variable:
```
#The directory of the repository, please set below Environment variable before use this script
# GIT_REPO_DIR_MAIN="/path/to/main/project/repository"
# GIT_REPO_DIR_SDK="/path/to/sdk/repository"
# MERGE_BRANCH_PREFIX="username_merge"
```

Hub protocol/user/oauth_token configuration:
```
# https://github.com/github/hub
# Error creating pull request: Unauthorized (HTTP 401)
# Bad credentials. The API can't be accessed using username/password authentication. Please create a personal access token to access this endpoint: http://github.com/settings/tokens
# visit http://github.com/settings/tokens to new personal access token

# https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/creating-a-personal-access-token
#     $ git clone https://github.com/username/repo.git
# Username: your_username
# Password: your_token

# If you need to interact with other repositories, generate a Personal Access Token with at least the repo scope and add it to your repository secrets.

# https://github.com/github/hub/issues/1067

# https://github.com/github/hub/issues/978
# Hub accesses GitHub API via HTTPS, so it needs some kind of authentication such as Basic Auth or OAuth. SSH keys won't help because they're only used by git when pushing/pulling.
# Because you don't have a password you can authenticate with, only 2FA token, that means you will probably need to generate a Personal access token manually.
# You can do that from your settings in the web interface. Then, add that token to ~/.config/hub like so:
# ---
# myenterprise.com:
# - protocol: https
#   user: tybenz
#   oauth_token: YOURTOKEN

# vim ~/.config/hub
# ---
# github.com:
# - protocol: https
#   user: GavinXiangPlanetArt
#   oauth_token: 038520c7c6ae81ccecba75f8c6554d7d06dd9d6d

# After setting ~/.config/hub, it works: https://github.com/Planetart/MyDealsSDK/pull/589

# https://hub.github.com/hub.1.html
#     GitHub OAuth authentication
# Hub will prompt for GitHub username & password the first time it needs to access the API and exchange it for an OAuth token, which it saves in ~/.config/hub.
# To avoid being prompted, use GITHUB_USER and GITHUB_PASSWORD environment variables.
# Alternatively, you may provide GITHUB_TOKEN, an access token with repo permissions. This will not be written to ~/.config/hub.
```

### Command:

**NOTE: push local commits before auto-merge,shell always merge branches from remote-tracking!**

*merge $source_branch to $target_branch*
`sh auto-merge-pr.sh main/sdk <target-branch> <source-branch>`

### Terminal Practice:
```
➜  MyDealsSDK git:(master) sh /Users/gavinxiang/Downloads/Shell-Collection/Git_auto-merge-pr/auto-merge-pr.sh sdk MD_3.67.0 master
hub installed
sdk
target_project is sdk
-e 

/Users/gavinxiang/Downloads/MyDealsSDK
remote: Enumerating objects: 19, done.
remote: Counting objects: 100% (19/19), done.
remote: Compressing objects: 100% (7/7), done.
remote: Total 19 (delta 13), reused 16 (delta 12), pack-reused 0
Unpacking objects: 100% (19/19), 3.34 KiB | 126.00 KiB/s, done.
From github.com:Planetart/fp_ios_mdsdk
   bce73c8da..589c57ab8  MD_3.66.6  -> origin/MD_3.66.6
   6f040f869..82ccc8260  MD_3.66.8  -> origin/MD_3.66.8
target_branch contains master
merge branch = FPA-000-Gavin_Merge_mst_to_MD_3.67.0
target branch name = MD_3.67.0, source branch name = master
-e 

merge branch does not exist, create it now...
branch 'FPA-000-Gavin_Merge_mst_to_MD_3.67.0' set up to track 'origin/MD_3.67.0'.
Switched to a new branch 'FPA-000-Gavin_Merge_mst_to_MD_3.67.0'
create merge branch success
-e 

Auto-merging mydeals/basic/Common/MDGlobal.m
Auto-merging mydeals/basic/FPUtility/Helper/MDAppKeysHelper.swift
CONFLICT (add/add): Merge conflict in mydeals/basic/FPUtility/Helper/MDAppKeysHelper.swift
Auto-merging mydeals/basic/FPUtility/Helper/MDAppsflyerManager.m
Automatic merge failed; fix conflicts and then commit the result.
merge failed: 1, please resolve conflict manaully!!!
```

**NOTE: If conflicts exist, resolve it, git merge --continue, then run shell again to create pull-request from current merge-branch.**

```
➜  MyDealsSDK git:(FPA-000-Gavin_Merge_mst_to_MD_3.67.0) ✗ git st
On branch FPA-000-Gavin_Merge_mst_to_MD_3.67.0
Your branch is up to date with 'origin/MD_3.67.0'.

You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)

Changes to be committed:
    modified:   mydeals/basic/Common/MDGlobal.m
    modified:   mydeals/basic/Helper/MDStoreInAppHelper.h
    modified:   mydeals/basic/Helper/MDStoreInAppHelper.m

Unmerged paths:
  (use "git add <file>..." to mark resolution)
    both added:      mydeals/basic/FPUtility/Helper/MDAppKeysHelper.swift

➜  MyDealsSDK git:(FPA-000-Gavin_Merge_mst_to_MD_3.67.0) ✗ open mydeals/basic/FPUtility/Helper/MDAppKeysHelper.swift
➜  MyDealsSDK git:(FPA-000-Gavin_Merge_mst_to_MD_3.67.0) ✗ git add .
➜  MyDealsSDK git:(FPA-000-Gavin_Merge_mst_to_MD_3.67.0) ✗ git st
On branch FPA-000-Gavin_Merge_mst_to_MD_3.67.0
Your branch is up to date with 'origin/MD_3.67.0'.

All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)

Changes to be committed:
    modified:   mydeals/basic/Common/MDGlobal.m
    modified:   mydeals/basic/Helper/MDStoreInAppHelper.h
    modified:   mydeals/basic/Helper/MDStoreInAppHelper.m

➜  MyDealsSDK git:(FPA-000-Gavin_Merge_mst_to_MD_3.67.0) ✗ git merge --continue
[FPA-000-Gavin_Merge_mst_to_MD_3.67.0 454462df7] Merge remote-tracking branch 'origin/master' into MD_3.67.0
➜  MyDealsSDK git:(FPA-000-Gavin_Merge_mst_to_MD_3.67.0) git st
On branch FPA-000-Gavin_Merge_mst_to_MD_3.67.0
Your branch is ahead of 'origin/MD_3.67.0' by 28 commits.
  (use "git push" to publish your local commits)

nothing to commit, working tree clean
➜  MyDealsSDK git:(FPA-000-Gavin_Merge_mst_to_MD_3.67.0) sh /Users/gavinxiang/Downloads/Shell-Collection/Git_auto-merge-pr/auto-merge-pr.sh sdk MD_3.67.0 master
hub installed
sdk
target_project is sdk
-e 

/Users/gavinxiang/Downloads/MyDealsSDK
target_branch contains master
merge branch = FPA-000-Gavin_Merge_mst_to_MD_3.67.0
target branch name = MD_3.67.0, source branch name = master
-e 

branch already exists
Already on 'FPA-000-Gavin_Merge_mst_to_MD_3.67.0'
Your branch is ahead of 'origin/MD_3.67.0' by 28 commits.
  (use "git push" to publish your local commits)
-e 

Already up to date.
merge success.
Enumerating objects: 19, done.
Counting objects: 100% (19/19), done.
Delta compression using up to 10 threads
Compressing objects: 100% (7/7), done.
Writing objects: 100% (7/7), 706 bytes | 706.00 KiB/s, done.
Total 7 (delta 6), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (6/6), completed with 6 local objects.
remote: 
remote: Create a pull request for 'FPA-000-Gavin_Merge_mst_to_MD_3.67.0' on GitHub by visiting:
remote:      https://github.com/Planetart/fp_ios_mdsdk/pull/new/FPA-000-Gavin_Merge_mst_to_MD_3.67.0
remote: 
To github.com:Planetart/fp_ios_mdsdk.git
 * [new branch]          FPA-000-Gavin_Merge_mst_to_MD_3.67.0 -> FPA-000-Gavin_Merge_mst_to_MD_3.67.0
branch 'FPA-000-Gavin_Merge_mst_to_MD_3.67.0' set up to track 'origin/FPA-000-Gavin_Merge_mst_to_MD_3.67.0'.
push success!
Switched to branch 'master'
Your branch is up to date with 'origin/master'.
Deleted branch FPA-000-Gavin_Merge_mst_to_MD_3.67.0 (was 454462df7).
https://github.com/Planetart/fp_ios_mdsdk/pull/6734
```
