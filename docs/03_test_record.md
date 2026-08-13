# Phase 1 test record

Date/time: 2026-08-06 13:48-14:52 CEST

Operator: Codex / anavs

## Jetson

```text
Model: NVIDIA Jetson AGX Orin Developer Kit
OS: Ubuntu 22.04.5 LTS
Architecture: aarch64
L4T: R36.3
Wired interface: eth0
Wired IP at test time: 192.168.7.68/24
Wi-Fi IP at test time: 192.168.7.140/24
```

## Kria

```text
OS: PetaLinux 2022.2 (Honister)
Architecture: aarch64
Wired interface: eth0
Wired IP at test time: 192.168.7.75/24
Heartbeat build: /data/builds/ROS2/kria_event_bridge_direct15
Heartbeat PID during test: 47858
Heartbeat log: /tmp/kria_heartbeat_publisher.log
```

## Shared ROS environment

```text
ROS_DISTRO=humble
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ROS_LOCALHOST_ONLY=0
```

## Evidence

```text
Jetson route to Kria: 192.168.7.75 dev eth0 src 192.168.7.68
Ping result: PASS, 4/4, 0% loss, average 0.680 ms
Firewall inspection: ufw is not installed; no firewall change was needed for
  the successful DDS test
ros2 doctor result: PASS; Humble active, rmw_fastrtps_cpp selected
rclcpp prefix: /opt/ros/humble
rmw_fastrtps_cpp prefix: /opt/ros/humble
Topic discovered: YES, publisher count 1
Topic type: std_msgs/msg/String
Publisher QoS: RELIABLE, VOLATILE, AUTOMATIC liveliness
Messages received: YES
Sample message:
  sequence=167 timestamp_ns=1786020718324061858 kria_alive
Observed rate: approximately 9.999 Hz over 15 seconds
Packet capture (if any):
Log files:
  logs/20_verify_2026-08-06_134841.log
  logs/25_local_smoke_2026-08-06_134927.log
  logs/25_local_pub_2026-08-06_134927.log
  logs/25_local_echo_2026-08-06_134927.log
  logs/25_local_hz_2026-08-06_134927.log
  logs/30_heartbeat_2026-08-06_145151.log
```

## Decision

Jetson installation result: `PASS`

Jetson local Fast DDS smoke test: `PASS` at approximately `10.000 Hz`

Cross-host heartbeat result: `PASS`

Overall phase 1 result: `PASS`

Notes: The Kria publisher is a compatibility experiment using the existing
isolated Ubuntu Humble runtime. The three ROS variables alone were insufficient:
the process initially failed on `libpython3.10.so.1.0`, and `ldd` also exposed
newer libstdc++, spdlog, and related dependencies. The successful test added
only process-local `LD_LIBRARY_PATH` and `AMENT_PREFIX_PATH` values pointing
to `/data/tools/kria-build-root` and the extracted ROS prefix. No libraries
were copied into the Kria system.

No event-camera, RVT, OpenEB, custom Event message, FPGA, overlay, Active
Marker, or Kria system changes were made: `YES`
