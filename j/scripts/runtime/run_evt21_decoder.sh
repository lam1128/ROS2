#!/usr/bin/env bash
set -eo pipefail
cd /home/anavs/ROS2
. /opt/ros/humble/setup.bash
. install/setup.bash
export ROS_DOMAIN_ID=42 RMW_IMPLEMENTATION=rmw_fastrtps_cpp ROS_LOCALHOST_ONLY=0
exec ros2 run jetson_evt21_decoder evt21_decoder_node
