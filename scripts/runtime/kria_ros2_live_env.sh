#!/usr/bin/env bash
# Source this file in the Kria shell that launches the live event driver.

# Do not change the caller's shell options when this file is sourced. In
# particular, `set -e` would terminate an interactive terminal whenever a
# command such as `ros2 run ...` returns a non-zero status. Keep strict mode
# for the less common case where this file is executed as a standalone script.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
fi

workspace=/data/workspaces/ROS2
ros_prefix=/data/tools/ros2-humble-20231122/ros2-linux
cpp_prefix=/data/tools/ros2-humble-cpp-overlay
sysroot=/data/tools/kria-build-root
openeb_prefix=/data/builds/ROS2/openeb-5.0.0-minimal
console_prefix=/data/builds/ROS2/console_bridge_20260806/install2
driver_install="$(find /data/builds/ROS2 -maxdepth 7 -type d -path '*/install/metavision_driver' | sort | tail -1)"
event_install="$(find /data/builds/ROS2 -maxdepth 7 -type d -path '*/install/event_camera_msgs' | sort | tail -1)"
ros_python_site="$(find "${ros_prefix}/lib" -type d -name site-packages -print -quit)"

test -x "${driver_install}/lib/metavision_driver/driver_node" || {
  echo "ERROR: no built metavision_driver found" >&2; return 1 2>/dev/null || exit 1;
}

export PATH="${ros_prefix}/bin:${sysroot}/usr/bin:${PATH}"
export PYTHONPATH="${ros_python_site}:${PYTHONPATH:-}"
export AMENT_PREFIX_PATH="${driver_install}:${event_install}:${console_prefix}:${cpp_prefix}:${ros_prefix}"
export CMAKE_PREFIX_PATH="${driver_install}:${event_install}:${console_prefix}:${cpp_prefix}:${ros_prefix}:${sysroot}/usr"
export LD_LIBRARY_PATH="${driver_install}/lib:${event_install}/lib:${console_prefix}/lib:${ros_prefix}/lib:${openeb_prefix}/lib:${sysroot}/usr/lib:${sysroot}/usr/lib/aarch64-linux-gnu:${sysroot}/lib:${LD_LIBRARY_PATH:-}"
export ROS_VERSION=2
export ROS_DISTRO=humble
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-42}"
export ROS_LOCALHOST_ONLY="${ROS_LOCALHOST_ONLY:-0}"
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_fastrtps_cpp}"
export V4L2_HEAP=reserved
export V4L2_SENSOR_PATH=/dev/v4l-subdev3

echo "ROS2 live runtime: ${driver_install}"
