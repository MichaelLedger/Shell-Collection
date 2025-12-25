# Firebase App Distribution - Fastlane Integration

This document describes how to use the `firebase_app_distribution` fastlane action for distributing iOS builds to testers.

## Overview

Firebase App Distribution makes distributing your apps to trusted testers painless. By getting your apps onto testers' devices quickly, you can get feedback early and often.

## Prerequisites

### 1. Install the Plugin

The plugin is automatically installed when running the lane if not present:

```ruby
unless File.exist?("fastlane/Pluginfile") && File.read("fastlane/Pluginfile").include?("fastlane-plugin-firebase_app_distribution")
    UI.message("Installing firebase_app_distribution plugin...")
    sh("bundle exec fastlane add_plugin firebase_app_distribution")
end
```

Or manually add to your `Pluginfile`:

```ruby
gem 'fastlane-plugin-firebase_app_distribution'
```

Then run:

```bash
bundle install
```

### 2. Authentication

You need a **Google Service Account** with Firebase App Distribution Admin role.

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a Service Account with "Firebase App Distribution Admin" role
3. Download the JSON key file
4. Place it in your fastlane directory (e.g., `fastlane/photo-books-e0fb835b5e8a.json`)

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `FIREBASE_APP_ID` | Firebase App ID | `1:123456789:ios:abcd1234` |
| `FIREBASE_IPA_PATH` | Path to the IPA file | `./build/MyApp.ipa` |
| `FIREBASE_TOKEN` | Path to service credentials JSON | `./fastlane/service-account.json` |
| `FIREBASE_GROUP` | Tester group name(s) | `internal-testers` |

### Available Parameters

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `app` | String | - | Yes | Your app's Firebase App ID |
| `ipa_path` | String | - | Yes (iOS) | Path to your IPA file |
| `apk_path` | String | - | Yes (Android) | Path to your APK file |
| `aab_path` | String | - | No | Path to your AAB file |
| `service_credentials_file` | String | - | No* | Path to service account JSON |
| `firebase_cli_token` | String | - | No* | Firebase CLI refresh token |
| `groups` | String | - | No | Tester group aliases (comma-separated) |
| `testers` | String | - | No | Tester emails (comma-separated) |
| `release_notes` | String | - | No | Release notes for this build |
| `release_notes_file` | String | - | No | Path to release notes file |
| `upload_timeout` | Integer | 300 | No | Upload timeout in seconds |
| `debug` | Boolean | false | No | Enable debug logging |

*One authentication method is required

## Usage Examples

### Basic Usage

```ruby
lane :distribute do
  firebase_app_distribution(
    app: "1:123456789:ios:abcd1234",
    ipa_path: "./build/MyApp.ipa",
    service_credentials_file: "./fastlane/service-account.json",
    groups: "internal-testers",
    release_notes: "Bug fixes and improvements"
  )
end
```

### With Extended Timeout (Recommended for Large IPAs)

```ruby
lane :distribute do
  firebase_app_distribution(
    app: "1:123456789:ios:abcd1234",
    ipa_path: "./build/MyApp.ipa",
    service_credentials_file: "./fastlane/service-account.json",
    groups: "internal-testers",
    release_notes: "Bug fixes and improvements",
    upload_timeout: 1200  # 20 minutes
  )
end
```

### With Git Changelog

```ruby
lane :distribute do
  commit_msgs = changelog_from_git_commits(
    commits_count: 10,
    pretty: "- %s",
    merge_commit_filtering: "exclude_merges"
  )
  
  firebase_app_distribution(
    app: ENV['FIREBASE_APP_ID'],
    ipa_path: ENV['FIREBASE_IPA_PATH'],
    service_credentials_file: ENV['FIREBASE_TOKEN'],
    groups: ENV['FIREBASE_GROUP'],
    release_notes: commit_msgs,
    upload_timeout: 1200
  )
end
```

### Complete Example (Current Project)

```ruby
desc "Push a new build to firebase appdistribution"
lane :appdistribution do
  # Generate release notes from git commits
  commit_msgs = changelog_from_git_commits(
    commits_count: 10,
    pretty: "- %s",
    merge_commit_filtering: "exclude_merges"
  )
  
  # Clean up commit messages
  msgArray = commit_msgs.split("\n")
  release_notes = ""
  msgArray.each { |item|
    strAppend = item.gsub("#comment", "")
    release_notes += (strAppend + "\n")
  }
  
  # Get configuration from environment
  app_id = ENV['FIREBASE_APP_ID']
  ipa_path = ENV['FIREBASE_IPA_PATH']
  token = ENV['FIREBASE_TOKEN']
  groups = ENV['FIREBASE_GROUP']
  
  # Ensure plugin is installed
  unless File.exist?("fastlane/Pluginfile") && File.read("fastlane/Pluginfile").include?("fastlane-plugin-firebase_app_distribution")
    UI.message("Installing firebase_app_distribution plugin...")
    sh("bundle exec fastlane add_plugin firebase_app_distribution")
  end
  
  # Upload to Firebase App Distribution
  firebase_app_distribution(
    app: app_id,
    service_credentials_file: token,
    ipa_path: ipa_path,
    groups: groups,
    release_notes: release_notes,
    upload_timeout: 1200  # 20 minutes for large IPA files
  )
end
```

## Timeout Configuration

The `upload_timeout` parameter controls how long the action waits for the upload to complete.

| Timeout Value | Duration | Recommended For |
|---------------|----------|-----------------|
| 300 (default) | 5 minutes | Small apps (< 50MB) |
| 600 | 10 minutes | Medium apps (50-100MB) |
| 1200 | 20 minutes | Large apps (100-200MB) |
| 1800 | 30 minutes | Very large apps (200MB+) |
| 3600 | 1 hour | Extra large apps or slow networks |

### Troubleshooting Timeout Issues

If you encounter `execution expired` errors:

1. **Increase timeout**: Set `upload_timeout` to a higher value
2. **Check IPA size**: Large IPAs take longer to upload
3. **Network stability**: Ensure stable internet connection on CI server
4. **Retry logic**: Implement retry mechanism for flaky connections

```ruby
# Example with retry
max_retries = 3
retry_count = 0

begin
  firebase_app_distribution(
    app: app_id,
    ipa_path: ipa_path,
    service_credentials_file: token,
    upload_timeout: 1800
  )
rescue => e
  retry_count += 1
  if retry_count <= max_retries
    UI.message("Upload failed, retrying (#{retry_count}/#{max_retries})...")
    sleep(30)
    retry
  else
    UI.error("Upload failed after #{max_retries} attempts")
    raise e
  end
end
```

## Tester Groups

### Creating Groups

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **App Distribution**
4. Click **Testers & Groups**
5. Create groups and add testers

### Using Multiple Groups

```ruby
firebase_app_distribution(
  app: app_id,
  ipa_path: ipa_path,
  groups: "internal-testers, qa-team, beta-users"
)
```

### Direct Tester Emails

```ruby
firebase_app_distribution(
  app: app_id,
  ipa_path: ipa_path,
  testers: "tester1@example.com, tester2@example.com"
)
```

## Release Notes

### Inline Notes

```ruby
firebase_app_distribution(
  release_notes: "Version 1.2.3\n- Bug fixes\n- New features"
)
```

### From File

```ruby
firebase_app_distribution(
  release_notes_file: "./RELEASE_NOTES.txt"
)
```

### From Git Commits

```ruby
notes = changelog_from_git_commits(
  commits_count: 10,
  pretty: "- %s"
)

firebase_app_distribution(
  release_notes: notes
)
```

## Command Line Usage

### View All Available Parameters

To see all available parameters and their descriptions, run:

```bash
bundle exec fastlane action firebase_app_distribution
```

**Sample Output:**

```
+-------------------------------------------------+
|                firebase_app_distribution                |
+-------------------------------------------------+
| Release your beta builds to Firebase App        |
| Distribution                                    |
+-------------------------------------------------+

+------------------------+-----------------------------------+------------------------+---------+
|                                   firebase_app_distribution Options                           |
+------------------------+-----------------------------------+------------------------+---------+
| Key                    | Description                       | Env Var                | Default |
+------------------------+-----------------------------------+------------------------+---------+
| app                    | Your app's Firebase App ID        | FIREBASEAPPDISTRO_APP  |         |
| firebase_cli_path      | Absolute path of the Firebase CLI | FIREBASEAPPDISTRO_     |         |
|                        |                                   | FIREBASE_CLI_PATH      |         |
| apk_path               | Path to the APK file              | FIREBASEAPPDISTRO_     |         |
|                        |                                   | APK_PATH               |         |
| aab_path               | Path to the AAB file              | FIREBASEAPPDISTRO_     |         |
|                        |                                   | AAB_PATH               |         |
| ipa_path               | Path to the IPA file              | FIREBASEAPPDISTRO_     |         |
|                        |                                   | IPA_PATH               |         |
| googleservice_info_    | Path to GoogleService-Info.plist  | FIREBASEAPPDISTRO_     |         |
| plist_path             |                                   | GOOGLESERVICE_INFO_    |         |
|                        |                                   | PLIST_PATH             |         |
| groups                 | The group aliases used for       | FIREBASEAPPDISTRO_     |         |
|                        | distribution, separated by commas | GROUPS                 |         |
| testers                | The email addresses of the       | FIREBASEAPPDISTRO_     |         |
|                        | testers you want to invite       | TESTERS                |         |
| release_notes          | Release notes for this build     | FIREBASEAPPDISTRO_     |         |
|                        |                                   | RELEASE_NOTES          |         |
| release_notes_file     | Path to release notes file       | FIREBASEAPPDISTRO_     |         |
|                        |                                   | RELEASE_NOTES_FILE     |         |
| firebase_cli_token     | Auth token for Firebase CLI      | FIREBASEAPPDISTRO_     |         |
|                        |                                   | FIREBASE_CLI_TOKEN     |         |
| service_credentials_   | Path to Google service account   | FIREBASEAPPDISTRO_     |         |
| file                   | json file                        | SERVICE_CREDENTIALS_   |         |
|                        |                                   | FILE                   |         |
| upload_timeout         | Amount of seconds before upload  | FIREBASEAPPDISTRO_     | 300     |
|                        | times out                        | UPLOAD_TIMEOUT         |         |
| debug                  | Print verbose debug output       | FIREBASEAPPDISTRO_     | false   |
|                        |                                   | DEBUG                  |         |
+------------------------+-----------------------------------+------------------------+---------+
```

### Other Useful Commands

```bash
# List all available actions
bundle exec fastlane actions

# Search for firebase related actions
bundle exec fastlane actions | grep firebase

# Get help for a specific action
bundle exec fastlane action firebase_app_distribution

# Run the distribution lane
bundle exec fastlane appdistribution

# Run with environment variables
FIREBASE_APP_ID="1:xxx:ios:xxx" \
FIREBASE_IPA_PATH="./build/App.ipa" \
FIREBASE_TOKEN="./fastlane/service-account.json" \
FIREBASE_GROUP="testers" \
bundle exec fastlane appdistribution

# Install the plugin manually
bundle exec fastlane add_plugin firebase_app_distribution

# Update all plugins
bundle exec fastlane update_plugins

# Check plugin version
bundle exec fastlane | grep firebase_app_distribution
```

### Running from CI/CD

```bash
# Jenkins / GitHub Actions / GitLab CI
cd PhotoBooks
bundle install
bundle exec fastlane ios appdistribution

# With specific environment
FIREBASE_APP_ID=$FIREBASE_APP_ID \
FIREBASE_IPA_PATH=$IPA_PATH \
FIREBASE_TOKEN=$SERVICE_ACCOUNT_PATH \
FIREBASE_GROUP=$TESTER_GROUP \
bundle exec fastlane ios appdistribution
```

## Debugging

Enable debug mode for verbose output:

```ruby
firebase_app_distribution(
  app: app_id,
  ipa_path: ipa_path,
  debug: true
)
```

Or via command line:

```bash
# Enable fastlane verbose mode
bundle exec fastlane appdistribution --verbose

# Enable debug environment variable
FIREBASEAPPDISTRO_DEBUG=true bundle exec fastlane appdistribution
```

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `execution expired` | Upload timeout | Increase `upload_timeout` |
| `401 Unauthorized` | Invalid credentials | Check service account permissions |
| `403 Forbidden` | Missing permissions | Ensure "Firebase App Distribution Admin" role |
| `App not found` | Wrong App ID | Verify `FIREBASE_APP_ID` |
| `IPA not found` | Wrong path | Verify `FIREBASE_IPA_PATH` |

## References

- [Official Firebase Documentation](https://firebase.google.com/docs/app-distribution/ios/distribute-fastlane)
- [GitHub Repository](https://github.com/fastlane/fastlane-plugin-firebase_app_distribution)
- [Fastlane Plugin Directory](https://docs.fastlane.tools/plugins/available-plugins/#firebase_app_distribution)

## Version History

| Date | Change |
|------|--------|
| 2025-12-25 | Added `upload_timeout: 1200` to handle large IPA uploads |

