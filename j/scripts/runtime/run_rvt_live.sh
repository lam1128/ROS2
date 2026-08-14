#!/usr/bin/env bash
set -eo pipefail
cd /home/anavs/ROS2
. /opt/ros/humble/setup.bash
. install/setup.bash
export ROS_DOMAIN_ID=42 RMW_IMPLEMENTATION=rmw_fastrtps_cpp ROS_LOCALHOST_ONLY=0 FASTDDS_BUILTIN_TRANSPORTS=UDPv4
exec docker run --rm --runtime nvidia --network host \
  -v /opt/ros/humble:/opt/ros/humble:ro \
  -v /usr/lib/aarch64-linux-gnu:/hostlibs:ro \
  -v /home/anavs/ROS2:/home/anavs/ROS2 \
  -v /home/anavs/jetson-containers/data/RVT:/home/anavs/jetson-containers/data/RVT:ro \
  rvt:jetson bash -lc '
    export ROS_DOMAIN_ID=42 RMW_IMPLEMENTATION=rmw_fastrtps_cpp ROS_LOCALHOST_ONLY=0 FASTDDS_BUILTIN_TRANSPORTS=UDPv4
    export PYTHONPATH=/opt/ros/humble/local/lib/python3.10/dist-packages:/opt/ros/humble/lib/python3.10/site-packages:/home/anavs/ROS2/install/rvt_live_inference/local/lib/python3.10/dist-packages:/home/anavs/ROS2/install/jetson_evt21_decoder/local/lib/python3.10/dist-packages:/home/anavs/jetson-containers/data/RVT
    export LD_LIBRARY_PATH=/hostlibs:/opt/ros/humble/lib:/home/anavs/ROS2/install/jetson_evt21_decoder/lib:/home/anavs/ROS2/install/rvt_live_inference/lib
    exec python3 /home/anavs/ROS2/install/rvt_live_inference/lib/rvt_live_inference/rvt_live_node --ros-args -p device:=cuda
  '
