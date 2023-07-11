#!/bin/sh
echo "==> Starting `jenkins-lts`"
brew services stop jenkins-lts
/opt/homebrew/opt/openjdk@17/bin/java -Dmail.smtp.starttls.enable=true -jar /opt/homebrew/opt/jenkins-lts/libexec/jenkins.war --httpListenAddress=10.4.2.5 --httpPort=8080
echo "==> Successfully started `jenkins-lts`"
