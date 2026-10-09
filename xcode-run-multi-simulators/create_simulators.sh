#!/bin/bash

# Create a simulator named "Custom Simulators" on the latest iOS runtime
# when it does not already exist. The device type is the newest plain iPhone
# (iPhone 17, iPhone 18, ...), not a hardcoded model.

custom_sim=$(xcrun simctl list devices | grep 'Custom Simulators' | awk -F'[()]' '{print $2}')

if [ -z "${custom_sim}" ]; then
  latest_ios_runtime=$(xcrun simctl list runtimes | grep iOS | grep -v unavailable | tail -1 | awk '{print $NF}')
  latest_iphone_type=$(xcrun simctl list devicetypes | sed -n 's/.*(\(com\.apple\.CoreSimulator\.SimDeviceType\.iPhone-[0-9][0-9]*\)).*/\1/p' | awk -F- '{ print $NF "\t" $0 }' | sort -n | tail -1 | cut -f2-)

  if [ -z "$latest_iphone_type" ] || [ -z "$latest_ios_runtime" ]; then
    echo "Could not resolve an iPhone device type or iOS runtime" >&2
    exit 1
  fi

  xcrun simctl create "Custom Simulators" "$latest_iphone_type" "$latest_ios_runtime"
fi
