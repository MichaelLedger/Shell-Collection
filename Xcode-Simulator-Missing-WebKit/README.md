## Xcode16+ Simulator Missing WebKit Crash Fix

Targets -> Build Phases -> New Run Script (At last)

```
if [ "$PLATFORM_NAME" == "iphonesimulator" ]; then
    # Match the simulator being run. SDK_VERSION is the Xcode SDK and can be newer
    # (for example SDK 27.0 while the destination simulator is iOS 18.5).
    RUNTIME_VERSION="${TARGET_DEVICE_OS_VERSION}"

    if [ -z "$RUNTIME_VERSION" ]; then
        echo "警告：未设置 TARGET_DEVICE_OS_VERSION，跳过复制 WebKit"
    else
        WEBKIT_PATH=$(find /Library/Developer/CoreSimulator/Volumes/*/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS\ ${RUNTIME_VERSION}*.simruntime/Contents/Resources/RuntimeRoot/System/Cryptexes/OS/System/Library/Frameworks/WebKit.framework/ -name "WebKit" -type f 2>/dev/null | head -1)

        if [ ! -f "$WEBKIT_PATH" ]; then
            WEBKIT_PATH=$(find /Library/Developer/CoreSimulator/Volumes/*/Library/Developer/CoreSimulator/Profiles/Runtimes/*/Contents/Resources/RuntimeRoot/System/Cryptexes/OS/System/Library/Frameworks/WebKit.framework/ -name "WebKit" -type f 2>/dev/null | while IFS= read -r path; do
                ver=${path#*Runtimes/iOS }
                ver=${ver%%.simruntime*}
                printf '%s\t%s\n' "$ver" "$path"
            done | sort -V | awk -F '\t' -v max="$RUNTIME_VERSION" '
                function cmp(a, b,    i, n, m, as, bs, av, bv) {
                    n = split(a, as, ".")
                    m = split(b, bs, ".")
                    if (m > n) n = m
                    for (i = 1; i <= n; i++) {
                        av = as[i] + 0
                        bv = bs[i] + 0
                        if (av < bv) return -1
                        if (av > bv) return 1
                    }
                    return 0
                }
                cmp($1, max) <= 0 { path = $2 }
                END { if (path != "") print path }
            ')
        fi

        if [ -f "$WEBKIT_PATH" ]; then
            echo "正在复制 WebKit 框架以解决 libswiftWebKit.dylib 问题: $WEBKIT_PATH"
            cp "$WEBKIT_PATH" "$BUILT_PRODUCTS_DIR/libswiftWebKit.dylib"
            echo "成功将 WebKit 复制到 BUILT_PRODUCTS_DIR"
        else
            echo "警告：无法找到不高于 iOS ${RUNTIME_VERSION} 的模拟器 WebKit 框架"
        fi
    fi
fi
```
