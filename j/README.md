# Jetson bundle

This directory contains the files needed on the Jetson side:

- `src/event_camera_msgs`: ROS2 event packet message
- `src/jetson_evt21_decoder`: EVT21 decoder
- `src/rvt_live_inference`: RVT ROS2 wrapper and browser overlay publisher
- `scripts/runtime/run_evt21_decoder.sh`: decoder launcher
- `scripts/runtime/run_rvt_live.sh`: RVT launcher
- `scripts/runtime/run_rvt_web_viewer.sh`: browser viewer launcher

The official RVT source and checkpoint remain outside this repository in the
Jetson container data directory.
