#!/bin/sh
set -eu

workspace_root=${ROS2_WORKSPACE_ROOT:-/data/workspaces/ROS2}
probe_root="$workspace_root/src/kria_sdk_probe"

test -f "$probe_root/CMakeLists.txt"
test -f "$probe_root/src/main.cpp"
test -f "$probe_root/README.md"

if grep -nE 'xmutil|loadapp|unloadapp|load-prophesee|/opt/metavision|/usr/bin' \
  "$probe_root/src/main.cpp" "$probe_root/CMakeLists.txt"; then
  echo "ERROR: probe contains a forbidden system/overlay operation." >&2
  exit 20
fi

if grep -nE 'rclcpp|ros2|ament' "$probe_root/src/main.cpp" "$probe_root/CMakeLists.txt"; then
  echo "ERROR: SDK-only probe unexpectedly depends on ROS2." >&2
  exit 21
fi

echo "Static SDK probe checks passed."
