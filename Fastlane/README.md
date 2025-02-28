fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios add_devices

```sh
[bundle exec] fastlane ios add_devices
```

Register Devices

Sample: fastlane ios add_devices

### ios match_lane

```sh
[bundle exec] fastlane ios match_lane
```

Match for appstore/enterprise/adhoc/development

Samples: fastlane ios match_lane type:<development//adhoc/appstore/enterprise> readonly:<true/false> force_for_new_devices:<true/false>

### ios match_appstore

```sh
[bundle exec] fastlane ios match_appstore
```

Match for appstore

Samples: fastlane ios match_appstore readonly:<true/false>

### ios match_adhoc

```sh
[bundle exec] fastlane ios match_adhoc
```

Match for adhoc

Samples: fastlane ios match_adhoc readonly:<true/false>

### ios match_development

```sh
[bundle exec] fastlane ios match_development
```

Match for development

Samples: fastlane ios match_development readonly:<true/false>

### ios match_enterprise

```sh
[bundle exec] fastlane ios match_enterprise
```

Match for enterprise

Samples: fastlane ios match_enterprise readonly:<true/false>

### ios match_all

```sh
[bundle exec] fastlane ios match_all
```

Match for appstore, adhoc and development

Samples: fastlane ios match_all readonly:<true/false>

### ios set_build_num

```sh
[bundle exec] fastlane ios set_build_num
```

Set build num as svn revision

### ios all

```sh
[bundle exec] fastlane ios all
```

Push a adhoc build to App Center and a release build to the App Store

### ios release

```sh
[bundle exec] fastlane ios release
```

Push a new release build to the App Store

### ios testflight

```sh
[bundle exec] fastlane ios testflight
```

Push a new build to TestFlight without bumping the app version in App Connect

### ios appcenter_pgy

```sh
[bundle exec] fastlane ios appcenter_pgy
```

Push a new build to App Center and PGY

### ios appcenter

```sh
[bundle exec] fastlane ios appcenter
```

Push a new build to App Center

### ios pgy

```sh
[bundle exec] fastlane ios pgy
```



### ios push_appcenter

```sh
[bundle exec] fastlane ios push_appcenter
```

Upload the ipa and dSYM to hockeyapp

### ios profile_appstore

```sh
[bundle exec] fastlane ios profile_appstore
```

Fetch appstore provisioning profiles

### ios profile_adhoc

```sh
[bundle exec] fastlane ios profile_adhoc
```

Fetch adhoc provisioning profiles

### ios compile_only

```sh
[bundle exec] fastlane ios compile_only
```

Compile the project only

### ios fill_development_environment_flag

```sh
[bundle exec] fastlane ios fill_development_environment_flag
```

Fill in development environment flag

### ios delete_development_environment_flag

```sh
[bundle exec] fastlane ios delete_development_environment_flag
```

Delete development environment flag

### ios fill_debug_amplitude_id

```sh
[bundle exec] fastlane ios fill_debug_amplitude_id
```

Fill in debug id for Amplitude

### ios fill_production_amplitude_id

```sh
[bundle exec] fastlane ios fill_production_amplitude_id
```

Fill in production id for Amplitude

### ios authenticating_with_apple_services

```sh
[bundle exec] fastlane ios authenticating_with_apple_services
```

Authenticating with Apple services

### ios review_submodules

```sh
[bundle exec] fastlane ios review_submodules
```

Review submodules commit-id

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

----

# Jenkins Practical Guide
## AdHoc Only
Build Environment -> Inject environment variables to the build process -> Properties Content
```
TARGET_NAME=US
FASTLANE_USER=xxx@xxx.cn
FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT = 10
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
BUILD_XCODEPATH=/Applications/Xcode.app
XCODE_SELECT=/Applications/Xcode.app
MATCH_PASSWORD=xxx
DEVICES_PATH=./fastlane/devices.txt
SUBMODULE_BRANCH_MAPPING={"XXX/SDK":"3.80.0"}
BUILD_NUM=888888
```
Build Environment -> Inject passwords to the build as environment variables -> Job passwords
`FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` & `FASTLANE_PASSWORD`
☑️ Mask passwords parameters
Build Steps -> Execute shell
```
cd ./XXX
bundle install
# Warnings Begin：Cannot delete sub module detection script
fastlane review_submodules
# Warnings End：

#rm -rf /Users/administrator/Library/Developer/Xcode/DerivedData/
#fastlane profile_adhoc
#sed -i "" "2s/xxx1@xxx.cn/xxx2@xxx.cn/g" ./fastlane/Appfile

rm -rf DerivedData/

xcodebuild -workspace ./xxx.xcworkspace -scheme xxus clean
export TARGET_NAME=US
fastlane appcenter_pgy
#bundle exec fastlane ios appcenter_pgy_appdistribution --env xxus --verbose
./Pods/FirebaseCrashlytics/upload-symbols -gsp ./xxus/GoogleService-Info.plist -p ios XXX.app.dSYM.zip
rm XXX.app.dSYM.zip

xcodebuild -workspace ./xxx.xcworkspace -scheme xxuk clean
export TARGET_NAME=UK
#fastlane pgy
#fastlane appcenter
fastlane appcenter_pgy
#bundle exec fastlane ios appcenter_pgy_appdistribution --env xxuk --verbose
./Pods/FirebaseCrashlytics/upload-symbols -gsp ./xxuk/GoogleService-Info.plist -p ios XXX.app.dSYM.zip
rm XXX.app.dSYM.zip
```

## AppStore Only
Build Environment -> Inject environment variables to the build process -> Properties Content
```
TARGET_NAME=US
FASTLANE_USER=xxx@xxx.cn
FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT = 10
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
BUILD_XCODEPATH=/Applications/Xcode.app
XCODE_SELECT=/Applications/Xcode.app
MATCH_PASSWORD=xxx
DEVICES_PATH=./fastlane/devices.txt
SUBMODULE_BRANCH_MAPPING={"XXX/SDK":"3.79.0"}
```
Build Environment -> Inject passwords to the build as environment variables -> Job passwords
`FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` & `FASTLANE_PASSWORD`
☑️ Mask passwords parameters
Build Steps -> Execute shell
```
cd ./XXX

# Warnings Begin：Cannot delete sub module detection script
bundle exec fastlane review_submodules
# Warnings End：

rm -rf DerivedData/

xcodebuild -workspace ./XXX.xcworkspace -scheme xxus clean
export TARGET_NAME=US
fastlane release
./Pods/FirebaseCrashlytics/upload-symbols -gsp ./xxus/GoogleService-Info.plist -p ios XXX.app.dSYM.zip
rm XXX.app.dSYM.zip

xcodebuild -workspace ./XXX.xcworkspace -scheme xxuk clean
export TARGET_NAME=UK
fastlane release
./Pods/FirebaseCrashlytics/upload-symbols -gsp ./xxuk/GoogleService-Info.plist -p ios XXX.app.dSYM.zip
rm XXX.app.dSYM.zip
```

## AdHoc & AppStore
Build Environment -> Inject environment variables to the build process -> Properties Content
```
TEAM_ID = XXXXXXXXXX
```
Build Steps -> Execute shell
```
~/.rbenv/shims/bundle install
# ~/.rbenv/shims/bundle update fastlane
~/.rbenv/shims/bundle exec pod select Podfile.release
~/.rbenv/shims/bundle exec pod install --repo-update
~/.rbenv/shims/bundle exec fastlane adhoc_and_app_store --env sti
```
Inject environment variables -> Properties File Path
`$WORKSPACE/myenv.properties`

Post-build Actions -> Update JIRA Issues (jira-ext-plugin)
JIRA Operations -> Comment
```
* STI Build Uploaded*
- ${FASTLANE_BUILD_INFO}
```
Post-build Actions -> Execute shell
```
versionNum=$(echo $FASTLANE_BUILD_INFO|awk '{print $2,$4}'|python3 -c "import urllib.parse;print (urllib.parse.quote(input()))"||true)
echo "+++++++++++++++++ $versionNum"
curl -I -u auto:xxx111 "http://x.x.3.5:8080/view/SA%20Automation/view/iOS/job/STA_AUTO_iOS/buildWithParameters?token=abc-123&versionNumSTA=$versionNum"
```

### lane :`write_build_info_to_file` write to `myenv.properties`
```
platform :ios do

    desc "Write Fastlane build info to myenv.properties"
    desc "Sample: fastlane ios write_build_info_to_file"
    lane :write_build_info_to_file do
        build_number_input = get_build_number_from_plist(target: target_name, plist_build_setting_support: true)
        version_number_input = get_version_number_from_plist(target: target_name, plist_build_setting_support: true)
        build_info_input = "#{target_name} #{version_number_input} build #{build_number_input}"
        puts("build_info ==> #{build_info_input}")
        puts("ENV File ==> #{workspace}/myenv.properties")
        File.write("#{workspace}/myenv.properties", "FASTLANE_BUILD_INFO=#{build_info_input.to_s}\n")

        commit = last_git_commit
        hash = commit[:commit_hash]
        File.write("#{workspace}/myenv.properties", "COMMIT_ID=#{hash.to_s}", mode:"a")
        puts("COMMIT_ID=#{build_info_input.to_s}==>myenv.properties")
    end
end
```
```
% cat myenv.properties
FASTLANE_BUILD_INFO=XXX 1.3 build 1140
COMMIT_ID=xxx8160c59cb691d6e6819503f7736ab680fcxxx
```

## `fastlane ios add_devices`: Adding a new device to App Store Connect's `Certificates, Identifiers & Profiles`
```
// Macbook -> system report
Hardware UUID:    XXXXXXXX-2EC2-59A2-8B67-XXXXXXXXXXXX
Provisioning UDID:    00006040-000811D80C0XXXXX

/Users/XXX/Downloads/XXX/XXX.xcodeproj Provisioning profile "match Development com.xxx.xxx" doesn't include the currently selected device "XXX’s MacBook Pro" (identifier 00006040-000811D80C0XXXXX).
```

devices.txt
```
Device ID    Device Name
00006040-000811D80C0XXXXX    SH-iOS-XXX-MPR-M4
```

```
XCODE_SELECT=/Applications/Xcode.app TARGET_NAME=US DEVICES_PATH=./fastlane/devices.txt bundle exec fastlane ios add_devices
```

## `fastlane ios match_all` has to set `readonly:false` to including new devices
```
% cat match_all.shell 
bundle exec fastlane ios match_all readonly:false --env fpus --verbose
bundle exec fastlane ios match_all readonly:false --env fpuk --verbose
```
