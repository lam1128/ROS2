#!/usr/bin/env bash
set -eo pipefail
ROS2_WS=/home/anavs/ROS2/j
cd "$ROS2_WS"
. /opt/ros/humble/setup.bash
. install/setup.bash
export ROS_DOMAIN_ID=42 RMW_IMPLEMENTATION=rmw_fastrtps_cpp ROS_LOCALHOST_ONLY=0
exec ros2 run jetson_evt21_decoder evt21_decoder_node
