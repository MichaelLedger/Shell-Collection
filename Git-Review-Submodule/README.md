# Git-Review-Submodule
> python script to quick review main project's all submodules commit-id is updated with specific branch's HEAD commit-id.

## Preprations
This script could integrate into fastlane by custom fastlane action which makes a developer's life easier.

Just inject environment variables via Jenkins plugin [Environment Injector] likes:

**key -> relative_path, value -> submodule_branch_name**

`SUBMODULE_BRANCH_MAPPING={"Calendar/MyDealsSDK":"MDGC_1.1.0"}`

## Usage

### By Terminal
1. cd to your main project git root path
2. custom `submodule_branch_mapping_str` in `review_submodule_commit.py`
2. run python script
`% python3 review_submodule_commit.py`

### By Jenkins & fastlane
1. cd to your fastlane root path

2. inject environment variables `SUBMODULE_BRANCH_MAPPING` via Jenkins plugin if you use fastlane & Jenkins

Build Environment -> Inject environment variables to the build process -> Properties Content

`SUBMODULE_BRANCH_MAPPING={"Calendar/MyDealsSDK":"MDGC_1.1.0"}`

3. custom fastlane action `review_submodules_commit`

`% fastlane new_action`

recheck action: `% bundle exec fastlane action review_submodules_commit`

4. replace file in `actions/review_submodules_commit.rb`

5. define lane in `Fastfile`

```
desc "Review submodules commit-id"
lane :review_submodules do |options|
    # UI.message "hello world"
    review_submodules_commit(options)    
end
```
5. Build Steps -> Execute Shell -> Command

**remember always cd to fastlane root path before running below command**
`fastlane review_submodules`

## Example

**bundle exec fastlane action review_submodules_commit**
```
➜  fastlane git:(FPA-000-TEST-Submodule-Jenkins) bundle exec fastlane action review_submodules_commit
[✔] 🚀 
+---------------------------+---------+------------------------------------+
|                               Used plugins                               |
+---------------------------+---------+------------------------------------+
| Plugin                    | Version | Action                             |
+---------------------------+---------+------------------------------------+
| fastlane-plugin-pgyer     | 0.2.5   | pgyer                              |
| fastlane-plugin-appcenter | 2.1.0   | appcenter_codepush_release_react,  |
|                           |         | appcenter_fetch_devices,           |
|                           |         | appcenter_fetch_version_number,    |
|                           |         | appcenter_upload                   |
+---------------------------+---------+------------------------------------+

Loading documentation for review_submodules_commit:

+-------------------------------------+
|      review_submodules_commit       |
+-------------------------------------+
| Review submodules commit-id         |
|                                     |
| Created by gavin.xiang@planetart.cn |
+-------------------------------------+

No available options
* = default value is dependent on the user's system

+---------------------------------------+---------------------------------------------------+
|                         review_submodules_commit Output Variables                         |
+---------------------------------------+---------------------------------------------------+
| Key                                   | Description                                       |
+---------------------------------------+---------------------------------------------------+
| REVIEW_SUBMODULES_COMMIT_RESULT_VALUE | review submodule commit result value (true/false) |
+---------------------------------------+---------------------------------------------------+
Access the output values using `lane_context[SharedValues::VARIABLE_NAME]`

More information can be found on https://docs.fastlane.tools/actions/review_submodules_commit
```

**Jenkins Console Output - Reject**
```
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar
main_project_path: /Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule
submodule_branch_mapping: {'Calendar/MyDealsSDK': 'MDGC_1.1.0'}
{'Calendar/MyDealsSDK': 'ecbd61b12318750fc8bd8a91bcdc5ce90b95b029'}
submodule.Calendar/MyDealsSDK.path Calendar/MyDealsSDK
Calendar/MyDealsSDK
sumbmodule_absolute_path: /Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar/MyDealsSDK
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar/MyDealsSDK
remote_fetch_url: git@github.com:Planetart/fp_ios_mdsdk.git
submodule_remote_urls_mapping: {'Calendar/MyDealsSDK': 'git@github.com:Planetart/fp_ios_mdsdk.git'}
branch_name: MDGC_1.1.0
remote_head_commit_id: 6c5fc087913831034333a1ddbe5214c68071168e
local_commit_id: ecbd61b12318750fc8bd8a91bcdc5ce90b95b029
['Calendar/MyDealsSDK'] submodule audit failed! 😢
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar
[14:36:29]: Result: false
+---------------------------------------+-----------------------+
|                         [33mLane Context[0m                          |
+---------------------------------------+-----------------------+
| DEFAULT_PLATFORM                      | ios                   |
| PLATFORM_NAME                         | ios                   |
| LANE_NAME                             | ios review_submodules |
| REVIEW_SUBMODULES_COMMIT_RESULT_VALUE | false                 |
+---------------------------------------+-----------------------+
[14:36:29]: [31mWhoops, something went wrong[0m

+------+--------------------------+-------------+
|               [32mfastlane summary[0m                |
+------+--------------------------+-------------+
| Step | Action                   | Time (in s) |
+------+--------------------------+-------------+
| 1    | default_platform         | 0           |
| 2    | default_platform         | 0           |
| 💥   | [31mreview_submodules_commit[0m | 4           |
+------+--------------------------+-------------+

[14:36:29]: [31mfastlane finished with errors[0m
[31m
[!] Whoops, something went wrong[0m
Build step 'Execute shell' marked build as failure
Finished: FAILURE
```

**Jenkins Console Output - Pass**
```
[EnvInject] - Variables injected successfully.
[EnvInject] - Mask passwords that will be passed as build parameters.
[GC_Test_Submodule] $ /bin/sh -xe /var/folders/hy/j9n2lbf55936kckly26hqq980000gn/T/jenkins16606195637470725683.sh
+ cd ./Calendar
+ fastlane review_submodules
[14:39:15]: [33mfastlane detected a Gemfile in the current directory[0m
[14:39:15]: [33mHowever, it seems like you didn't use `bundle exec`[0m
[14:39:15]: [33mTo launch fastlane faster, please use[0m
[14:39:15]: 
[14:39:15]: [36m$ bundle exec fastlane review_submodules[0m

[14:39:16]: [32mDriving the lane 'ios review_submodules' 🚀[0m
[14:39:16]: [32m--------------------------------------[0m
[14:39:16]: [32m--- Step: review_submodules_commit ---[0m
[14:39:16]: [32m--------------------------------------[0m
[14:39:16]: script_path /Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar/fastlane/scripts/review_submodule_commit.py
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar
main_project_path: /Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule
submodule_branch_mapping: {'Calendar/MyDealsSDK': 'MDGC_1.1.0'}
{'Calendar/MyDealsSDK': '6c5fc087913831034333a1ddbe5214c68071168e'}
submodule.Calendar/MyDealsSDK.path Calendar/MyDealsSDK
Calendar/MyDealsSDK
sumbmodule_absolute_path: /Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar/MyDealsSDK
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar/MyDealsSDK
remote_fetch_url: git@github.com:Planetart/fp_ios_mdsdk.git
submodule_remote_urls_mapping: {'Calendar/MyDealsSDK': 'git@github.com:Planetart/fp_ios_mdsdk.git'}
branch_name: MDGC_1.1.0
remote_head_commit_id: 6c5fc087913831034333a1ddbe5214c68071168e
local_commit_id: 6c5fc087913831034333a1ddbe5214c68071168e
['Calendar/MyDealsSDK'] submodule audit passed! 😊
[🎉] All submodules audit passed! 🍺
/Volumes/ExDisk/Jenkins-workspace/GC_Test_Submodule/Calendar
[14:39:20]: Result: true

+------+--------------------------+-------------+
|               [32mfastlane summary[0m                |
+------+--------------------------+-------------+
| Step | Action                   | Time (in s) |
+------+--------------------------+-------------+
| 1    | default_platform         | 0           |
| 2    | default_platform         | 0           |
| 3    | review_submodules_commit | 4           |
+------+--------------------------+-------------+

[14:39:20]: [32mfastlane.tools finished successfully 🎉[0m
Finished: SUCCESS
```

## Fastlane: Is there a way to exit/end/return/quit/abort with success a lane?

Yeah, you can use

`UI.user_error!("Whoops, something went wrong")`

to fail the current lane.

Nothing for finishing a lane, you can always do that using if else blocks

## Reference
[How to see which commit a git submodule points at](https://stackoverflow.com/questions/20655073/how-to-see-which-commit-a-git-submodule-points-at)

[Fastlane高级用法：自定义脚本的调用](https://juejin.cn/post/7114598669348782117)

[fastlane 实现自定义Action](https://www.jianshu.com/p/44bbe1a31b52)

[Exit lane] (https://github.com/fastlane/fastlane/issues/5913)
