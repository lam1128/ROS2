# Kria bundle

This directory contains the files needed on the Kria side:

- `src/event_camera_msgs`: ROS2 event packet message
- `src/metavision_driver`: IMX636/EVT21 publisher and configuration
- `src/metavision_driver/config/kria_imx636_evt21.yaml`: camera configuration
- `scripts/runtime/kria_ros2_live_env.sh`: runtime environment helper

The Kria runtime launcher currently lives on the board at
`/data/workspaces/ROS2/scripts/runtime/run_kria_evt21_driver.sh`.
