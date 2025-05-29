#!/bin/bash
# This script is designed to run as a pre-action script in Xcode to prepare simulators for testing.

# After running the build, you can check the logs by opening Terminal and typing:
# cat /tmp/simulator_preaction.log
# Create log file
LOG_FILE="/tmp/simulator_preaction.log"
echo "Starting multi-platform script at $(date)" > "$LOG_FILE"

# Get the app path
APP_NAME=$(xcrun xcodebuild -showBuildSettings -project "${PROJECT_FILE_PATH}" -target "${TARGET_NAME}" | grep "FULL_PRODUCT_NAME" | sed 's/.*= \(.*\)/\1/')
echo "Initial APP_NAME: $APP_NAME" >> "$LOG_FILE"

if [ -z "$APP_NAME" ]; then
    APP_NAME="${TARGET_NAME}.app"
    echo "Using fallback APP_NAME: $APP_NAME" >> "$LOG_FILE"
fi

BUILT_PRODUCTS_DIR="${BUILT_PRODUCTS_DIR}"
APP_PATH="${BUILT_PRODUCTS_DIR}/${APP_NAME}"
echo "App path: $APP_PATH" >> "$LOG_FILE"

# Get bundle ID
BUNDLE_ID=$(defaults read "$APP_PATH/Info" CFBundleIdentifier)
echo "Bundle ID: $BUNDLE_ID" >> "$LOG_FILE"

# Extract UDIDs using grep for the specific pattern: 8-4-4-4-12 hex digits in parentheses
# Function to find simulator by exact name
find_simulator_by_name() {
    local device_name=$1
    xcrun simctl list devices available | grep "$device_name" | grep -v unavailable | tail -1 | grep -o -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
}

# Function to find latest simulator for a device type
find_latest_simulator() {
    local device_name=$1
    # Get all matching simulators, then take the last one (latest)
    xcrun simctl list devices available | grep "$device_name" | grep -v unavailable | tail -1 | grep -o -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
}

# Function to ensure a simulator is booted
ensure_booted() {
    local device_name=$1
    local udid=$2

    # Check if device is already booted
    local status=$(xcrun simctl list devices | grep "$udid" | grep -o "(Booted)" || echo "(Not Booted)")

    if [[ "$status" == "(Booted)" ]]; then
        echo "$device_name is already booted" >> "$LOG_FILE"
    else
        echo "Booting $device_name..." >> "$LOG_FILE"
        xcrun simctl boot "$udid" >> "$LOG_FILE" 2>&1
        # Small delay to ensure boot completes
        sleep 2
    fi
}

# Function to process a device
process_device() {
    local device_name=$1
    local udid=$2

    if [ ! -z "$udid" ]; then
        echo "Processing $device_name ($udid)..." >> "$LOG_FILE"

        # Make sure the simulator is booted
        ensure_booted "$device_name" "$udid"

        # Uninstall app if it exists
        echo "Uninstalling existing app on $device_name..." >> "$LOG_FILE"
        xcrun simctl uninstall "$udid" "$BUNDLE_ID" >> "$LOG_FILE" 2>&1 || true

        echo "Installing on $device_name..." >> "$LOG_FILE"
        xcrun simctl install "$udid" "$APP_PATH" >> "$LOG_FILE" 2>&1

        echo "Launching on $device_name..." >> "$LOG_FILE"
        xcrun simctl launch "$udid" "$BUNDLE_ID" >> "$LOG_FILE" 2>&1
    else
        echo "No simulator found for $device_name" >> "$LOG_FILE"
    fi
}

# Define devices to process
DEVICE_NAMES=(
    "iPhone" # latest generic iPhone
    "iPad" # latest generic iPad
    "Plus" # custom device name
    "Pro Max" # custom device name
    "11-inch" # custom device name
    "13-inch" # custom device name
    # Add more specific device names as needed
)

# Process  # Custom device type
    # each device type
for DEVICE_NAME in "${DEVICE_NAMES[@]}"; do
    echo "Looking for device: $DEVICE_NAME" >> "$LOG_FILE"
    
    # Try to find exact match first, then fall back to generic type
    UDID=$(find_simulator_by_name "$DEVICE_NAME")
    
    # If it's a generic type (iPhone/iPad) and no exact match was found,
    # get the latest of that type
    if [ -z "$UDID" ] && [[ "$DEVICE_NAME" == "iPhone" || "$DEVICE_NAME" == "iPad" ]]; then
        echo "No exact match found for $DEVICE_NAME, finding latest" >> "$LOG_FILE"
        UDID=$(find_latest_simulator "$DEVICE_NAME")
    fi
    
    echo "$DEVICE_NAME UDID: $UDID" >> "$LOG_FILE"
    process_device "$DEVICE_NAME" "$UDID"
done

echo "Multi-platform script completed at $(date)" >> "$LOG_FILE"
exit 0
