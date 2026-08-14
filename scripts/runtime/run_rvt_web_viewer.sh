#!/usr/bin/env bash
set -eo pipefail

ROS2_WS=/home/anavs/ROS2
cd "$ROS2_WS"
. /opt/ros/humble/setup.bash
. install/setup.bash

export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_LOCALHOST_ONLY=0
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4

exec docker run --rm --runtime nvidia --network host \
  -v /opt/ros/humble:/opt/ros/humble:ro \
  -v /usr/lib/aarch64-linux-gnu:/hostlibs:ro \
  -v "$ROS2_WS":"$ROS2_WS" \
  rvt:jetson bash -lc '
    export ROS_DOMAIN_ID=42 RMW_IMPLEMENTATION=rmw_fastrtps_cpp ROS_LOCALHOST_ONLY=0 FASTDDS_BUILTIN_TRANSPORTS=UDPv4
    export PYTHONPATH=/opt/ros/humble/local/lib/python3.10/dist-packages:/opt/ros/humble/lib/python3.10/site-packages:/home/anavs/ROS2/install/rvt_live_inference/local/lib/python3.10/dist-packages:/home/anavs/ROS2/install/jetson_evt21_decoder/local/lib/python3.10/dist-packages
    export LD_LIBRARY_PATH=/hostlibs:/opt/ros/humble/lib:/home/anavs/ROS2/install/jetson_evt21_decoder/lib:/home/anavs/ROS2/install/rvt_live_inference/lib
    exec python3 /home/anavs/ROS2/install/rvt_live_inference/lib/rvt_live_inference/rvt_web_viewer.py
  '
