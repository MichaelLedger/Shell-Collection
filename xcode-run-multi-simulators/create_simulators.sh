#!/bin/bash

# Check if Custom Simulators exists, create if it doesn't exist
custom_sim=`xcrun simctl list | grep 'Custom Simulators' | awk -F'[()]' '{print $2}'`

if [ -z "${custom_sim}" ]; then
  # Get the latest iOS runtime version
  latest_ios_runtime=`xcrun simctl list runtimes | grep iOS | tail -1 | awk '{print $NF}'`
  xcrun simctl create Custom\ Simulators com.apple.CoreSimulator.SimDeviceType.iPhone-16 ${latest_ios_runtime}
fi
