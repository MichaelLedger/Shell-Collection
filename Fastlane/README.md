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
