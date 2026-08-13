#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/config/jetson_ros2_env.sh"

echo "== System =="
cat /etc/os-release
uname -m

echo
echo "== ROS environment =="
printenv | grep -E \
  '^(ROS_DISTRO|ROS_DOMAIN_ID|RMW_IMPLEMENTATION|ROS_LOCALHOST_ONLY)=' \
  | sort

echo
echo "== Stop stale daemon =="
ros2 daemon stop || true

echo
echo "== ROS doctor =="
ros2 doctor --report

echo
echo "== Required package prefixes =="
ros2 pkg prefix rclcpp
ros2 pkg prefix rmw_fastrtps_cpp

echo
echo "== Versions =="
ros2 --help | sed -n '1,8p'
colcon version-check 2>/dev/null || colcon --help | sed -n '1,8p'

