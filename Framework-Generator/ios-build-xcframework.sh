#!/bin/bash

# Detect project type and get first available scheme
if [ -e *.xcworkspace ]; then
    BUILD_CMD="xcodebuild -workspace *.xcworkspace"
    echo "Using workspace for build..."
elif [ -e *.xcodeproj ]; then
    BUILD_CMD="xcodebuild -project *.xcodeproj"
    echo "Using project for build..."
else
    echo "Error: No .xcworkspace or .xcodeproj found"
    exit 1
fi

# Get first available scheme
echo "Fetching available schemes..."
SCHEME_NAME=$(${BUILD_CMD} -list | grep -A 1 "Schemes:" | tail -n 1 | xargs)
if [ -z "$SCHEME_NAME" ]; then
    echo "Error: No schemes found in the project"
    exit 1
fi

FMK_NAME=$SCHEME_NAME

echo "Using scheme and framework name: ${SCHEME_NAME}"

# Install dir will be the final output to the xcframework
SRCROOT=$(pwd)
INSTALL_DIR=${SRCROOT}/Products
XCFRAMEWORK_PATH="${INSTALL_DIR}/${FMK_NAME}.xcframework"

# Update build paths for archives
ARCHIVE_PATH="${SRCROOT}/build/archive"
DEVICE_ARCHIVE_PATH="${ARCHIVE_PATH}/device.xcarchive"
SIMULATOR_ARCHIVE_PATH="${ARCHIVE_PATH}/simulator.xcarchive"
CATALYST_ARCHIVE_PATH="${ARCHIVE_PATH}/catalyst.xcarchive"

# Clean up any existing products
if [ -d "${INSTALL_DIR}" ]; then
    echo "Removing existing framework..."
    rm -rf "${INSTALL_DIR}"
fi

mkdir -p "${INSTALL_DIR}"

# Build for iOS devices (arm64)
echo "Building for iPhone OS (arm64)..."
xcodebuild archive \
    -scheme "${FMK_NAME}" \
    -archivePath "${DEVICE_ARCHIVE_PATH}" \
    -sdk iphoneos \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO || exit 1

# Build for iOS Simulator (arm64, x86_64)
echo "Building for iPhone Simulator (arm64, x86_64)..."
xcodebuild archive \
    -scheme "${FMK_NAME}" \
    -archivePath "${SIMULATOR_ARCHIVE_PATH}" \
    -sdk iphonesimulator \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO || exit 1

# Build for Mac Catalyst (optional, uncomment if needed)
# echo "Building for Mac Catalyst..."
# xcodebuild archive \
#     -scheme "${FMK_NAME}" \
#     -archivePath "${CATALYST_ARCHIVE_PATH}" \
#     -destination 'platform=macOS,variant=Mac Catalyst' \
#     SKIP_INSTALL=NO \
#     BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
#     SUPPORTS_MACCATALYST=YES || exit 1

# Create XCFramework
echo "Creating XCFramework..."
# Basic command with iOS and Simulator
XCFRAMEWORK_CMD="xcodebuild -create-xcframework \
    -framework ${DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${FMK_NAME}.framework \
    -framework ${SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${FMK_NAME}.framework"

# Add Mac Catalyst if it was built (uncomment if needed)
# if [ -d "${CATALYST_ARCHIVE_PATH}" ]; then
#     XCFRAMEWORK_CMD="${XCFRAMEWORK_CMD} \
#     -framework ${CATALYST_ARCHIVE_PATH}/Products/Library/Frameworks/${FMK_NAME}.framework"
# fi

# Add output path
XCFRAMEWORK_CMD="${XCFRAMEWORK_CMD} -output ${XCFRAMEWORK_PATH}"

# Execute XCFramework creation
eval "${XCFRAMEWORK_CMD}" || exit 1

echo "Cleaning up build directory..."
rm -rf "${ARCHIVE_PATH}"

echo "Revealing XCFramework in Finder..."
open -R "${XCFRAMEWORK_PATH}"

echo "XCFramework successfully created at: ${XCFRAMEWORK_PATH}"

# Verify XCFramework contents and architectures
echo "\n=== XCFramework Information ==="
# List all frameworks in the XCFramework
echo "XCFramework contents:"
lipo -info "${XCFRAMEWORK_PATH}"/*framework/${FMK_NAME} 2>/dev/null || true

# More detailed information using dwarfdump
echo "\nDetailed architecture information:"
for framework in "${XCFRAMEWORK_PATH}"/*framework; do
    echo "\nChecking framework: ${framework##*/}"
    dwarfdump --arch all "${framework}/${FMK_NAME}" 2>/dev/null || true
done

echo "\nXCFramework Info.plist contents:"
plutil -p "${XCFRAMEWORK_PATH}"/Info.plist
echo "======================================\n"
