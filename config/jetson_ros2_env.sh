#!/usr/bin/env bash

if [[ ! -r /opt/ros/humble/setup.bash ]]; then
  echo "ROS 2 Humble is not installed at /opt/ros/humble." >&2
  return 1 2>/dev/null || exit 1
fi

# ROS-generated setup files may probe optional variables before defining them.
_JETSON_ROS2_RESTORE_NOUNSET=0
if [[ "$-" == *u* ]]; then
  _JETSON_ROS2_RESTORE_NOUNSET=1
  set +u
fi
source /opt/ros/humble/setup.bash
if [[ -r /home/anavs/ROS2/install/setup.bash ]]; then
  source /home/anavs/ROS2/install/setup.bash
fi
if [[ "${_JETSON_ROS2_RESTORE_NOUNSET}" -eq 1 ]]; then
  set -u
fi
unset _JETSON_ROS2_RESTORE_NOUNSET

export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_LOCALHOST_ONLY=0
