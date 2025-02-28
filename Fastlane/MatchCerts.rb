
# ----------- apple developer variables
ITC_TEAM_ID = "100000000" # App Store Connect Team ID for enterprise

TEAM_ID = "XXXXXXXXXX" # Developer Portal Team ID for enterprise

DEVELOPMENT_CERTS_GIT_URL = "git@github.com:MichaelLedger/ios-certificates.git"

DISTRIBUTION_CERTS_GIT_URL = "git@github.com:MichaelLedger/ios-certificates-distribution.git"

GIT_BRANCH = "xx"

# ----------- apple developer variables
itc_team_id = "100000000" # App Store Connect Team ID for enterprise

team_id = "XXXXXXXXXX" # Developer Portal Team ID for enterprise

development_certs_git_url = "git@github.com:MichaelLedger/ios-certificates.git"

distribution_certs_git_url = "git@github.com:MichaelLedger/ios-certificates-distribution.git"

git_branch = "XX"

scheme = "scheme"
target_name = ENV['TARGET_NAME']
app_identifier = "com.MichaelLedger.xxxx"
app_extension_id = "com.MichaelLedger.xxxx.notificationServiceExt-xx"
app_backgroundDownload_extension_id = "com.MichaelLedger.xxxx.backgroundDownloadExt-xx"
targets = Array["DE", "ES", "FR", "IE", "IN", "IT", "NL", "UK", "US","CA"]
devices_path = ENV['DEVICES_PATH']
is_enterprise = ENV['IS_ENTERPRISE']
target_up = target_name.upcase
target_down = target_name.downcase
isIncluded = targets.include?(target_up)
app_share_extension_id = ""

if isIncluded
    scheme = "xx#{target_down}"
    app_identifier = "com.MichaelLedger.xx#{target_down}"
    app_extension_id = "com.MichaelLedger.xx#{target_down}.notificationServiceExt-#{target_down}"
    app_backgroundDownload_extension_id = "com.MichaelLedger.xx#{target_down}.backgroundDownloadExt-#{target_down}"
    if target_up == "CA"
      app_identifier = "com.MichaelLedger.xxcanada"
      app_extension_id = "com.MichaelLedger.xxcanada.notificationServiceExt-#{target_down}"
      app_backgroundDownload_extension_id = "com.MichaelLedger.xxcanada.backgroundDownloadExt-#{target_down}"
      app_share_extension_id = app_identifier + ".#{scheme}Share"
    elsif target_up != "US"
      app_share_extension_id = app_identifier + ".#{scheme}Share"
    end
end

puts "Does current target exists ? #{isIncluded}. scheme = #{scheme}, appid = #{app_identifier}, app_ext_id = #{app_extension_id}, app_backgroundDownload_ext_id = #{app_backgroundDownload_extension_id}"
if target_up == "US"
  app_identifier = "com.development.xxx"
  app_extension_id = "com.development.xxx.notificationServiceExt-us"
  app_backgroundDownload_extension_id = "com.development.xxx.backgroundDownloadExt-us"
  app_share_extension_id = app_identifier + ".xxusShare"
end

extension_identifiers = app_extension_id.split(",")
extension_backgroundDownload_identifiers = app_backgroundDownload_extension_id.split(",")

default_platform(:ios)

platform :ios do
    desc "Register Devices"
    desc "Sample: fastlane ios add_devices"
    lane :add_devices do
      if lane_context[SharedValues::APP_STORE_CONNECT_API_KEY].nil?
        authenticating_with_apple_services
      end
      register_devices(devices_file: devices_path)
    end 
  
     desc "Match for appstore/enterprise/adhoc/development"
     desc "Samples: fastlane ios match_lane type:<development//adhoc/appstore/enterprise> readonly:<true/false> force_for_new_devices:<true/false>"
     lane :match_lane do |options|
       readonly = options[:readonly]
       certs_git_url = options[:certs_git_url]
       type = options[:type]
       force_for_new_devices = options[:force_for_new_devices]
       if force_for_new_devices.nil?
         force_for_new_devices = false
       end
   
       app_identifiers = extension_identifiers.insert(0, app_identifier)
       app_identifiers = app_identifiers + extension_backgroundDownload_identifiers
       if app_share_extension_id != ""
        app_identifiers = app_identifiers + app_share_extension_id.split(",")
       end

       puts("all app ids====#{app_identifier}")

       if lane_context[SharedValues::APP_STORE_CONNECT_API_KEY].nil?
                   authenticating_with_apple_services
       end
   
       match(
         team_id: team_id,
         git_url: certs_git_url,
         git_branch: git_branch,
         app_identifier: app_identifiers,
         type: type,
         shallow_clone: false,
         fail_on_name_taken: true,
         force_for_new_devices: force_for_new_devices,
         readonly: readonly,
         verbose: true,
         include_mac_in_profiles:true
       )
     end
   
     desc "Match for appstore"
     desc "Samples: fastlane ios match_appstore readonly:<true/false>"
     lane :match_appstore do |options|
       readonly = options[:readonly]
       match_lane(type: 'appstore', readonly:readonly, certs_git_url: distribution_certs_git_url, force_for_new_devices: false)
     end
   
     desc "Match for adhoc"
     desc "Samples: fastlane ios match_adhoc readonly:<true/false>"
     lane :match_adhoc do |options|
       readonly = options[:readonly]
       match_lane(type: 'adhoc', readonly:readonly, certs_git_url: distribution_certs_git_url, force_for_new_devices: true)
     end
   
     desc "Match for development"
     desc "Samples: fastlane ios match_development readonly:<true/false>"
     lane :match_development do |options|
       readonly = options[:readonly]
       match_lane(type: 'development', readonly:readonly, certs_git_url: development_certs_git_url, force_for_new_devices: true)
     end
   
     desc "Match for enterprise"
     desc "Samples: fastlane ios match_enterprise readonly:<true/false>"
     lane :match_enterprise do |options|
       readonly = options[:readonly]
       match_lane(type: 'enterprise', readonly:readonly, certs_git_url: development_certs_git_url, force_for_new_devices: false)
     end
     
     desc "Match for appstore, adhoc and development"
     desc "Samples: fastlane ios match_all readonly:<true/false>"
     lane :match_all do |options|
       readonly = options[:readonly]
  
       add_devices()
  
       match_development(readonly:readonly)
   
       UI.message "Current Apple Developer Acccount is enterprise account: #{is_enterprise}"
   
       if is_enterprise.nil?
         match_adhoc(readonly:readonly)
         match_appstore(readonly:readonly)
       elsif is_enterprise == "true"
         match_enterprise(readonly:readonly)
       else
         match_adhoc(readonly:readonly)
         match_appstore(readonly:readonly)
       end
   
     end
   
   end
