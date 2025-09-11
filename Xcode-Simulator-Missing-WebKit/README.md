## Xcode16+ Simulator Missing WebKit Crash Fix

Targets -> Build Phases -> New Run Script (At last)

```
if [ "$PLATFORM_NAME" == "iphonesimulator" ] && [[ "$SDK_VERSION" == "18.5"* ]]; then
    WEBKIT_PATH=$(find /Library/Developer/CoreSimulator/Volumes/*/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS\ 18.5.simruntime/Contents/Resources/RuntimeRoot/System/Cryptexes/OS/System/Library/Frameworks/WebKit.framework/ -name "WebKit" -type f 2>/dev/null | head -1)
    
    if [ -f "$WEBKIT_PATH" ]; then
        echo "正在复制 WebKit 框架以解决 libswiftWebKit.dylib 问题"
        cp "$WEBKIT_PATH" "$BUILT_PRODUCTS_DIR/libswiftWebKit.dylib"
        echo "成功将 WebKit 复制到 BUILT_PRODUCTS_DIR"
    else
        echo "警告：无法找到 iOS 18.5 模拟器的 WebKit 框架"
    fi
fi

if [ "$PLATFORM_NAME" == "iphonesimulator" ] && [[ "$SDK_VERSION" == "26.0"* ]]; then
    WEBKIT_PATH=$(find /Library/Developer/CoreSimulator/Volumes/*/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS\ 26.0.simruntime/Contents/Resources/RuntimeRoot/System/Cryptexes/OS/System/Library/Frameworks/WebKit.framework/ -name "WebKit" -type f 2>/dev/null | head -1)
    
    if [ -f "$WEBKIT_PATH" ]; then
        echo "正在复制 WebKit 框架以解决 libswiftWebKit.dylib 问题"
        cp "$WEBKIT_PATH" "$BUILT_PRODUCTS_DIR/libswiftWebKit.dylib"
        echo "成功将 WebKit 复制到 BUILT_PRODUCTS_DIR"
    else
        echo "警告：无法找到 iOS 26.0 模拟器的 WebKit 框架"
    fi
fi
```
