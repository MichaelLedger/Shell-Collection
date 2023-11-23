if [ "${CONFIGURATION}" != "Debug" ]; then
    exit 0
fi 

# Get build products path
productsPath="${BUILT_PRODUCTS_DIR}"
cd "${productsPath}"
cd "${PRODUCT_NAME}.app"

# BackgroundDownloadExt

#<key>EXAppExtensionAttributes</key>
#<dict>
#    <key>EXExtensionPointIdentifier</key>
#    <string>com.apple.background-asset-downloader-extension</string>
#    <key>EXPrincipalClass</key>
#    <string>BackgroundDownloadHandler</string>
#</dict>

if [ -d "Extensions" ]; then
    cd "Extensions"
    extensionList=$(find . -type d -name "*backgroundDownloadExt_*")
    for extension in $extensionList; do
        echo "remove $extension"
        rm -rf "$extension"
    done
    cd ..
fi

# ServiceExt

#<key>NSExtension</key>
#<dict>
#    <key>NSExtensionPointIdentifier</key>
#    <string>com.apple.usernotifications.service</string>
#    <key>NSExtensionPrincipalClass</key>
#    <string>NotificationService</string>
#</dict>

if [ -d "PlugIns" ]; then
    cd "PlugIns"
    extensionList=$(find . -type d -name "*notificationServiceExt_*")
    for extension in $extensionList; do
        echo "remove $extension"
        rm -rf "$extension"
    done
    cd ..
fi

# WidgetKit
#<key>NSExtension</key>
#<dict>
#    <key>NSExtensionPointIdentifier</key>
#    <string>com.apple.widgetkit-extension</string>
#</dict>

if [ -d "PlugIns" ]; then
    cd "PlugIns"
    extensionList=$(find . -type d -name "*WidgetExtension*")
    for extension in $extensionList; do
        echo "remove $extension"
        rm -rf "$extension"
    done
    cd ..
fi
