# Jetson EVT21 decoder

This package decodes the raw vectorized EVT21 payload published by the Kria
driver. It publishes `jetson_evt21_decoder/msg/DecodedEventPacket` containing
one entry per CD event (`x`, `y`, camera timestamp `t`, and polarity).

Build on the Jetson, where ROS2 Humble and `event_camera_msgs` are installed:

```bash
cd ~/ROS2
colcon build --packages-select event_camera_msgs jetson_evt21_decoder
source install/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_LOCALHOST_ONLY=0
ros2 run jetson_evt21_decoder evt21_decoder_node
```

Default topics:

```text
input:  /metavision_driver/events
output: /metavision_driver/events_decoded
```

The output is a generic decoded-event boundary for the future RVT adapter. It
does not itself run inference or publish detections.
