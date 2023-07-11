# Jenkins Installation

## Mac Info

Mac Mini 2023 with Apple M2 Pro

MacOS Ventura 13.4.1

https://www.macminivault.com/installing-jenkins-on-macos/

## 1. Install HomeBrew
macmini@iOSBuildMachine-M2Pro-25 ~ % which brew
brew not found

macmini@iOSBuildMachine-M2Pro-25 ~ % ruby -version
ruby 2.6.10p210 (2022-04-12 revision 67958) [universal.arm64e-darwin22]
-e:1:in `<main>': undefined local variable or method `rsion' for main:Object (NameError)

macmini@iOSBuildMachine-M2Pro-25 ~ % /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

Warning: /opt/homebrew/bin is not in your PATH.
  Instructions on how to configure your shell for Homebrew
  can be found in the 'Next steps' section below.
==> Installation successful!

==> Homebrew has enabled anonymous aggregate formulae and cask analytics.
Read the analytics documentation (and how to opt-out) here:
  https://docs.brew.sh/Analytics
No analytics data has been sent yet (nor will any be during this install run).

==> Homebrew is run entirely by unpaid volunteers. Please consider donating:
  https://github.com/Homebrew/brew#donations

==> Next steps:
- Run these two commands in your terminal to add Homebrew to your PATH:
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/macmini/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
- Run brew help to get started
- Further documentation:
    https://docs.brew.sh
    
macmini@iOSBuildMachine-M2Pro-25 ~ % (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/macmini/.zprofile
macmini@iOSBuildMachine-M2Pro-25 ~ % eval "$(/opt/homebrew/bin/brew shellenv)"
macmini@iOSBuildMachine-M2Pro-25 ~ % which brew                                                                          
/opt/homebrew/bin/brew
macmini@iOSBuildMachine-M2Pro-25 ~ % brew -v
Homebrew 4.0.28

`% brew doctor`
Your system is ready to brew.

## 2. Install Java11 or newer

**Before installing Jenkins, we need to install a specific version of Java11 or newer required by Jenkins!**

macmini@iOSBuildMachine-M2Pro-25 ~ % which java
/usr/bin/java

macmini@iOSBuildMachine-M2Pro-25 ~ % /usr/bin/java --version
The operation couldn’t be completed. Unable to locate a Java Runtime.
Please visit http://www.java.com for information on installing Java.

`% brew install openjdk@11`

`% brew install java11`

macmini@iOSBuildMachine-M2Pro-25 ~ % brew info openjdk
==> openjdk: stable 20.0.1 (bottled) [keg-only]
Development kit for the Java programming language
https://openjdk.java.net/
Not installed
From: https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/openjdk.rb
License: GPL-2.0-only with Classpath-exception-2.0
==> Dependencies
Build: autoconf ✘, pkg-config ✘
Required: giflib ✔, harfbuzz ✔, jpeg-turbo ✔, libpng ✔, little-cms2 ✔
==> Requirements
Build: Xcode (on macOS) ✔
Required: macOS >= 10.15 (or Linux) ✔
==> Caveats
For the system Java wrappers to find this JDK, symlink it with
  sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk

openjdk is keg-only, which means it was not symlinked into /opt/homebrew,
because macOS provides similar software and installing this software in
parallel can cause all kinds of trouble.
==> Analytics
install: 82,590 (30 days), 493,677 (90 days), 504,707 (365 days)
install-on-request: 41,822 (30 days), 377,457 (90 days), 386,432 (365 days)
build-error: 219 (30 days)

**Verify it's for the arm64 hardware:**
macmini@iOSBuildMachine-M2Pro-25 ~ % file $(brew --prefix openjdk@11)/bin/java
/opt/homebrew/opt/openjdk@11/bin/java: Mach-O 64-bit executable arm64

## 3. Install Jenkins

https://www.jenkins.io/doc/book/installing/macos/

> jenkins LTS vs Weekly

Stable (LTS) releases are chosen every 12 weeks from the stream of regular releases, and patched every 4 weeks with bug, security fix, and minor feature backports. Regular (Weekly) releases deliver bug fixes and new features rapidly to users and plugin developers who need them.

https://www.jenkins.io/download/lts/macos/

Jenkins can be installed using the Homebrew package manager. Homebrew formula: jenkins-lts This is a package supported by a third party which may be not as frequently updated as packages supported by the Jenkins project directly.

Sample commands:
Install the latest LTS version: `brew install jenkins-lts`
Install a specific LTS version: `brew install jenkins-lts@YOUR_VERSION`
Start the Jenkins service: `brew services start jenkins-lts`
Restart the Jenkins service: `brew services restart jenkins-lts`
Update the Jenkins version: `brew upgrade jenkins-lts`

macmini@iOSBuildMachine-M2Pro-25 ~ % brew install jenkins-lts
==> Installing jenkins-lts
==> Pouring jenkins-lts--2.401.2.arm64_ventura.bottle.tar.gz
==> Caveats
Note: When using launchctl the port will be 8080.

To start jenkins-lts now and restart at login:
  brew services start jenkins-lts
Or, if you don't want/need a background service you can just run:
  /opt/homebrew/opt/openjdk@17/bin/java -Dmail.smtp.starttls.enable=true -jar /opt/homebrew/opt/jenkins-lts/libexec/jenkins.war --httpListenAddress=127.0.0.1 --httpPort=8080
==> Summary
🍺  /opt/homebrew/Cellar/jenkins-lts/2.401.2: 8 files, 97.1MB
==> Running `brew cleanup jenkins-lts`...
Disable this behaviour by setting HOMEBREW_NO_INSTALL_CLEANUP.
Hide these hints with HOMEBREW_NO_ENV_HINTS (see `man brew`).
==> Caveats
==> jenkins-lts
Note: When using launchctl the port will be 8080.

To start jenkins-lts now and restart at login:
  brew services start jenkins-lts
Or, if you don't want/need a background service you can just run:
  /opt/homebrew/opt/openjdk@17/bin/java -Dmail.smtp.starttls.enable=true -jar /opt/homebrew/opt/jenkins-lts/libexec/jenkins.war --httpListenAddress=127.0.0.1 --httpPort=8080

## 4. Start Jenkins

macmini@iOSBuildMachine-M2Pro-25 ~ % brew services start jenkins-lts
==> Tapping homebrew/services
Cloning into '/opt/homebrew/Library/Taps/homebrew/homebrew-services'...
remote: Enumerating objects: 2458, done.
remote: Counting objects: 100% (2458/2458), done.
remote: Compressing objects: 100% (1177/1177), done.
remote: Total 2458 (delta 1144), reused 2344 (delta 1093), pack-reused 0
Receiving objects: 100% (2458/2458), 674.28 KiB | 702.00 KiB/s, done.
Resolving deltas: 100% (1144/1144), done.
Tapped 1 command (45 files, 843.2KB).
==> Successfully started `jenkins-lts` (label: homebrew.mxcl.jenkins-lts)

## 5. Modify homebrew.mxcl.jenkins-lts.plist to make jenkins be accessible from anywhere (not just on the local machine)

**查看HomeBrew安装软件的配置文件路径**

macmini@iOSBuildMachine-M2Pro-25 ~ % brew services list
Name        Status  User    File
jenkins-lts started macmini ~/Library/LaunchAgents/homebrew.mxcl.jenkins-lts.plist

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>homebrew.mxcl.jenkins-lts</string>
        <key>LimitLoadToSessionType</key>
        <array>
                <string>Aqua</string>
                <string>Background</string>
                <string>LoginWindow</string>
                <string>StandardIO</string>
                <string>System</string>
        </array>
        <key>ProgramArguments</key>
        <array>
                <string>/opt/homebrew/opt/openjdk@17/bin/java</string>
                <string>-Dmail.smtp.starttls.enable=true</string>
                <string>-jar</string>
                <string>/opt/homebrew/opt/jenkins-lts/libexec/jenkins.war</string>
                <string>--httpListenAddress=127.0.0.1</string>
                <string>--httpPort=8080</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
</dict>
</plist>
```

**We want the Jenkins web interface to be accessible from anywhere (not just on the local machine), so we’re going to open up the config file.**

Please use **jenkins-lts homebrew config file path**

`sudo nano ~/Library/LaunchAgents/homebrew.mxcl.jenkins-lts.plist`

instead of 

`sudo nano /usr/local/opt/jenkins-lts/homebrew.mxcl.jenkins-lts.plist`

Find this line:

`<string>--httpListenAddress=127.0.0.1</string>`

And change it to:

`<string>--httpListenAddress=0.0.0.0</string>`

(to exit out of nano after making the change, hit Ctrl+X, hit Y to save the changes and hit Enter)

## 6. Input Administrator Password & Install Default Plugins for Beginners

Using Safari to open: http://localhost:8080

`$ cat ~/.jenkins/secrets/initialAdminPassword`

macmini@iOSBuildMachine-M2Pro-25 ~ % vim /Users/macmini/.jenkins/secrets/initialAdminPassword

c77e165a1389421b957a9b85386e00c4

**Just install the plugin for beginners!**

**实例配置**

**10.4.2.5 is your computer IP address via ethernet**

Jenkins URL: http://10.4.2.5:8080/

Jenkins URL 用于给各种Jenkins资源提供绝对路径链接的根地址。 这意味着对于很多Jenkins特色是需要正确设置的，例如：邮件通知、PR状态更新以及提供给构建步骤的BUILD_URL环境变量。
推荐的默认值显示在尚未保存，如果可能的话这是根据当前请求生成的。 最佳实践是要设置这个值，用户可能会需要用到。这将会避免在分享或者查看链接时的困惑。

## 7. Config Jenkins URL
Dashboard -> Manage Jenkins -> Configure System -> Jenkins URL -> http://10.4.2.5:8080/

restart jenkins: `% brew services restart jenkins-lts`

**It appears that your reverse proxy set up is broken.**

https://www.jenkins.io/doc/book/system-administration/reverse-proxy-configuration-troubleshooting/

https://stackoverflow.com/questions/34940805/jenkins-apache-reverse-proxy-error

Dashboard -> Manage Jenkins -> Configure System ->

/Users/macmini/.jenkins

macmini@iOSBuildMachine-M2Pro-25 ~ % vim /Users/macmini/.jenkins/jenkins.model.JenkinsLocationConfiguration.xml

```
BASE=administrativeMonitor/hudson.diagnosis.ReverseProxySetupMonitor
curl -iL -e http://your.reverse.proxy/jenkins/manage \
            http://your.reverse.proxy/jenkins/${BASE}/test
```
(assuming your Jenkins is located at http://your.reverse.proxy/jenkins/ - and is open to anonymous read access)

Mine:

```
BASE=administrativeMonitor/hudson.diagnosis.ReverseProxySetupMonitor
curl -iL -e http://10.4.2.5:8080/manage \
            http://10.4.2.5:8080/${BASE}/test
```

macmini@iOSBuildMachine-M2Pro-25 ~ % BASE=administrativeMonitor/hudson.diagnosis.ReverseProxySetupMonitor
curl -iL -e http://10.4.2.5:8080/manage \
            http://10.4.2.5:8080/${BASE}/test
curl: (7) Failed to connect to 10.4.2.5 port 8080 after 5 ms: Couldn't connect to server

macmini@iOSBuildMachine-M2Pro-25 ~ % ping 10.4.2.5
PING 10.4.2.5 (10.4.2.5): 56 data bytes
64 bytes from 10.4.2.5: icmp_seq=0 ttl=64 time=0.161 ms
64 bytes from 10.4.2.5: icmp_seq=1 ttl=64 time=0.232 ms
64 bytes from 10.4.2.5: icmp_seq=2 ttl=64 time=0.226 ms
64 bytes from 10.4.2.5: icmp_seq=3 ttl=64 time=0.221 ms
^C
--- 10.4.2.5 ping statistics ---
4 packets transmitted, 4 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 0.161/0.210/0.232/0.029 ms

**modify port number not useful!**

https://www.macminivault.com/installing-jenkins-on-macos/

**Currently we can only reinstall Jenkins**

`% brew services stop jenkins-lts`

**manually delete configurations files**

`% rm -R /Users/macmini/.jenkins`

`% brew reinstall jenkins-lts`

**Go back to Step 4. Start Jenkins & Step 5. Modify homebrew.mxcl.jenkins-lts.plist to make jenkins be accessible from anywhere (not just on the local machine)**

## 8. Close background service If you want the Jenkins web interface to be accessible from anywhere by running via IP address

`% /opt/homebrew/opt/openjdk@17/bin/java -Dmail.smtp.starttls.enable=true -jar /opt/homebrew/opt/jenkins-lts/libexec/jenkins.war --httpListenAddress=10.4.2.5 --httpPort=8080`

Then you can visit Jenkins via `http://10.4.2.5:8080`

## 9. Via VNC to copy exists jobs from other CI Machines

Finder -> Network -> CI Machine -> Connect

vnc://10.4.2.2

## 10. Install Plugins Timeout

http://10.4.2.5:8080/manage/pluginManager/advanced

https://updates.jenkins.io/current/update-center.json

java.net.SocketTimeoutException: Connect timed out

    at hudson.model.UpdateCenter$UpdateCenterConfiguration.download(UpdateCenter.java:1285)
Caused: java.io.IOException: Failed to download from https://updates.jenkins.io/download/plugins/xcode-plugin/2.0.17-565.v1c48051d46ef/xcode-plugin.hpi (redirected to: https://get.jenkins.io/plugins/xcode-plugin/2.0.17-565.v1c48051d46ef/xcode-plugin.hpi)
    at hudson.model.UpdateCenter$UpdateCenterConfiguration.download(UpdateCenter.java:1319)
    at hudson.model.UpdateCenter$DownloadJob._run(UpdateCenter.java:1876)
    at hudson.model.UpdateCenter$InstallationJob._run(UpdateCenter.java:2188)
    at hudson.model.UpdateCenter$DownloadJob.run(UpdateCenter.java:1850)
    at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
    at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
    at hudson.remoting.AtmostOneThreadExecutor$Worker.run(AtmostOneThreadExecutor.java:121)
    at java.base/java.lang.Thread.run(Thread.java:833)


https://plugins.jenkins.io/xcode-plugin

Error 503 Backend is unhealthy

Backend is unhealthy

Error 54113

Details: cache-hkg17929-HKG 1688731403 2481106926

Varnish cache server

与502错误网关错误的情况一样，诊断503错误的原因很困难。通常情况下，支持您尝试访问的网站的服务器出现问题。

1、503错误的最常见原因是服务器与其支持的网站之间的通信中断，导致该网站无法处理来自用户浏览器的任何信息请求。这可能是由于预定的服务器维护或一些不可预见的技术问题。如果是后者，您可能会发现某些网站比其他网站更频繁地关闭，这通常表明其托管服务提供商不足。

2、如果服务器仍然在线但缺乏足够的容量来支持访问网站的请求数量，也可能发生503错误。当一个通常流量较低的网站突然被大量新用户涌入时，通常会发生这种情况。

## 11. Create custom Terminal shortcuts like 'jenkins' to quick start jenkins

Create custom Terminal shortcuts

https://apple.stackexchange.com/questions/235182/create-custom-terminal-shortcuts

Simply add aliases in ~/.bash_profile:
If the file .bash_profile doesn't exist:
touch ~/.bash_profile
Then add aliases with nano ~/.bash_profile. Examples:
alias ssh01='ssh xyx@xy'
alias ssh02='ssh -NC user@xy -L 9999:localhost:3306'
Then source the file or restart Terminal.app:
source ~/.bash_profile
Entering ssh01 in the shell will then execute ssh xyx@xy or ssh02 the second command.
The alias (i.e. ssh01) mustn't be another valid command in your path (e.g ssh-add)

**custom httpListenAddress & httpPort as you need**

```
#!/bin/sh
echo "==> Starting `jenkins-lts`"
brew services stop jenkins-lts
/opt/homebrew/opt/openjdk@17/bin/java -Dmail.smtp.starttls.enable=true -jar /opt/homebrew/opt/jenkins-lts/libexec/jenkins.war --httpListenAddress=10.4.2.5 --httpPort=8080
echo "==> Successfully started `jenkins-lts`"
```

**copy startJenkins.sh to path `~/.jenkins`**

`% touch ~/.bash_profile`

`% sudo vim .bash_profile`

or

`% sudo nano .bash_profile`

```
alias jenkins='sh ~/.jenkins/startJenkins.sh'
```

% source ~/.bash_profile
**Need execute upper command everytime whenever you create new terminal window !**

% jenkins


