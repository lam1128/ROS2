# Kria ROS2 workspace

This directory is the Kria-side ROS2 workspace source. The live Kria
checkout is `/data/workspaces/ROS2`; this copy is kept in the repository so
Kria and Jetson code remain clearly separated.

It contains:

- `src/event_camera_msgs`: ROS2 event packet message
- `src/metavision_driver`: IMX636/EVT21 publisher and configuration
- `scripts/runtime/kria_ros2_live_env.sh`: runtime environment helper

The Kria runtime launcher currently lives on the board at
`/data/workspaces/ROS2/scripts/runtime/run_kria_evt21_driver.sh`.
