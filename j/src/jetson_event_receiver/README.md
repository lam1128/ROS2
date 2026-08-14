# Jetson EventPacket receiver

This C++ node receives the raw `event_camera_msgs/msg/EventPacket` stream from
the Kria and reports packet rate, payload bandwidth, sequence gaps, timestamp
regressions, unexpected encodings, and receive silence. It intentionally does
not decode EVT21; that decoder belongs between this transport monitor and the
RVT inference adapter.

Build and run on the Jetson:

```bash
colcon build --packages-select event_camera_msgs jetson_event_receiver
source install/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ros2 run jetson_event_receiver event_packet_receiver
```

The default topic is `/metavision_driver/events`, with a BEST_EFFORT,
VOLATILE queue depth of 4. Override parameters with, for example:

```bash
ros2 run jetson_event_receiver event_packet_receiver --ros-args \
  -p topic:=/metavision_driver/events -p queue_size:=4 -p report_period_sec:=2.0
```
