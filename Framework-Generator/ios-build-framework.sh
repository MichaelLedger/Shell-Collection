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

# Install dir will be the final output to the framework.
SRCROOT=$(pwd)
INSTALL_DIR=${SRCROOT}/Products/${FMK_NAME}.framework

# Update build paths for modern Xcode
ARCHIVE_PATH="${SRCROOT}/build/archive"
DEVICE_ARCHIVE_PATH="${ARCHIVE_PATH}/device.xcarchive"
SIMULATOR_ARCHIVE_PATH="${ARCHIVE_PATH}/simulator.xcarchive"

echo "Building for iPhone OS (arm64)..."
if ! xcodebuild archive \
    -scheme "${FMK_NAME}" \
    -archivePath "${DEVICE_ARCHIVE_PATH}" \
    -sdk iphoneos \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO; then
    echo "Error: Failed to build for iPhone OS"
    exit 1
fi

echo "Building for iPhone Simulator (x86_64)..."
if ! xcodebuild archive \
    -scheme "${FMK_NAME}" \
    -archivePath "${SIMULATOR_ARCHIVE_PATH}" \
    -sdk iphonesimulator \
    SKIP_INSTALL=NO \
    BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
    ARCHS="x86_64" \
    ONLY_ACTIVE_ARCH=NO; then
    echo "Error: Failed to build for iPhone Simulator"
    exit 1
fi

# Cleaning the oldest.
if [ -d "${INSTALL_DIR}" ]; then
    echo "Removing existing framework..."
    rm -rf "${INSTALL_DIR}"
fi

echo "Creating framework directory..."
if ! mkdir -p "${INSTALL_DIR}"; then
    echo "Error: Failed to create framework directory"
    exit 1
fi

# Update framework paths
DEVICE_FRAMEWORK_PATH="${DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${FMK_NAME}.framework"
SIMULATOR_FRAMEWORK_PATH="${SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${FMK_NAME}.framework"

# Debug information
echo "Checking paths:"
echo "Device Framework: ${DEVICE_FRAMEWORK_PATH}"
echo "Simulator Framework: ${SIMULATOR_FRAMEWORK_PATH}"

# Verify the files exist
if [ ! -f "${DEVICE_FRAMEWORK_PATH}/${FMK_NAME}" ]; then
    echo "Error: Device framework binary not found at: ${DEVICE_FRAMEWORK_PATH}/${FMK_NAME}"
    exit 1
fi

if [ ! -f "${SIMULATOR_FRAMEWORK_PATH}/${FMK_NAME}" ]; then
    echo "Error: Simulator framework binary not found at: ${SIMULATOR_FRAMEWORK_PATH}/${FMK_NAME}"
    exit 1
fi

echo "Copying device framework..."
if ! cp -R "${DEVICE_FRAMEWORK_PATH}/" "${INSTALL_DIR}/"; then
    echo "Error: Failed to copy device framework"
    exit 1
fi

echo "Creating universal framework..."
if ! lipo -create \
    "${DEVICE_FRAMEWORK_PATH}/${FMK_NAME}" \
    "${SIMULATOR_FRAMEWORK_PATH}/${FMK_NAME}" \
    -output "${INSTALL_DIR}/${FMK_NAME}"; then
    echo "Error: Failed to create universal framework"
    exit 1
fi

# Architecture verification
echo "\n=== Framework Architecture Information ==="
echo "Device binary architectures:"
lipo -info "${DEVICE_FRAMEWORK_PATH}/${FMK_NAME}"
echo "\nSimulator binary architectures:"
lipo -info "${SIMULATOR_FRAMEWORK_PATH}/${FMK_NAME}"
echo "\nFinal universal framework architectures:"
lipo -info "${INSTALL_DIR}/${FMK_NAME}"
echo "======================================\n"

# Verify the final universal framework
echo "Final universal framework architectures:"
lipo -info "${INSTALL_DIR}/${FMK_NAME}"

echo "Cleaning up build directory..."
rm -rf "${ARCHIVE_PATH}"

#echo "Opening framework directory..."
#open "${INSTALL_DIR}"

# Instead of trying to open the framework directly, show it in Finder
echo "Revealing framework in Finder..."
open -R "${INSTALL_DIR}"

echo "Framework successfully created at: ${INSTALL_DIR}"
