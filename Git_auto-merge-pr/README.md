# cmd_script - Auto merge branch and pull request
Some script for command line to improve productivity.

### Preparation:

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

*merge $source_branch to $target_branch*
`sh auto-merge-pr.sh main/sdk <target-branch> <source-branch>`

### Terminal Practice:
```
% sh /Users/gavin/Downloads/Shell-Collection/Git_auto-merge-pr/auto-merge-pr.sh sdk MD_1.5 Test-Auto-Merge-And-PR-Shell

hub installed
sdk
target_project is sdk
-e 

/Users/gavin/Downloads/freeprints_ios_3/FreePrints/MyDealsSDK
target branch name = MD_1.5, source branch name = Test-Auto-Merge-And-PR-Shell
-e 

merge branch does not exist, create it now...
Branch 'gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5' set up to track remote branch 'MD_1.5' from 'origin'.
Switched to a new branch 'gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5'
create merge branch success
-e 

Merge made by the 'recursive' strategy.
 mydeals/basic/Networking/MDAFNetworking.m | 1 +
 1 file changed, 1 insertion(+)
merge success.
Enumerating objects: 20, done.
Counting objects: 100% (18/18), done.
Delta compression using up to 4 threads
Compressing objects: 100% (10/10), done.
Writing objects: 100% (10/10), 952 bytes | 952.00 KiB/s, done.
Total 10 (delta 6), reused 0 (delta 0)
remote: Resolving deltas: 100% (6/6), completed with 6 local objects.
remote: 
remote: Create a pull request for 'gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5' on GitHub by visiting:
remote:      https://github.com/Planetart/MyDealsSDK/pull/new/gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5
remote: 
To github.com:Planetart/MyDealsSDK.git
 * [new branch]        gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5 -> gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5
Branch 'gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5' set up to track remote branch 'gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5' from 'origin'.
push success!
Switched to branch 'Test-Auto-Merge-And-PR-Shell'
Deleted branch gavin_merge_shell_Test-Auto-Merge-And-PR-Shell_to_MD_1.5 (was 450b474d).
https://github.com/Planetart/MyDealsSDK/pull/589
```

merge Test-Auto-Merge-And-PR-Shell to MD_1.5 #589
GavinXiangPlanetArt wants to merge 2 commits into MD_1.5 from gavin_merge_Test-Auto-Merge-And-PR-Shell_to_MD_1.5

