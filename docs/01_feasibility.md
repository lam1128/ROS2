# Feasibility assessment

Assessment date: 2026-08-06

## Result

Jetson-side phase 1 is feasible.

The machine is a Jetson AGX Orin running Ubuntu 22.04.5 on ARM64. ROS 2 Humble
Debian packages target Ubuntu 22.04 and are available for ARM64, so a native
Humble installation is appropriate. There is no reason to select Rolling,
Jazzy, or a source build for this phase.

The proposed package scope is sufficient to receive and inspect the existing
`/kria/heartbeat` topic:

- `ros-humble-ros-base`
- `ros-humble-rmw-fastrtps-cpp`
- `python3-colcon-common-extensions`
- `build-essential`
- `cmake`

`ros-humble-ros-base` supplies the ROS command-line and base runtime.
`rmw_fastrtps_cpp` makes the requested Fast DDS RMW explicit. The build tools
are present only for later C++ workspace work; no workspace or custom message
is created in phase 1.

## Confirmed locally

```text
PRETTY_NAME="Ubuntu 22.04.5 LTS"
VERSION_CODENAME=jammy
uname -m: aarch64
Jetson model: NVIDIA Jetson AGX Orin Developer Kit
L4T: R36.3
Disk available on /: approximately 1.4 TB
ros2: not installed
colcon: not installed
eth0: 192.168.7.68/24, up
wlan0: 192.168.7.140/24, up
default route: 192.168.7.1 via eth0 (metric 100)
clock synchronization: active
```

Ubuntu `universe` is already enabled. The ROS 2 APT source is not currently
configured.

## Risks and gates

1. Kria ROS 2 is not ready yet. Jetson installation and local verification can
   proceed, but the cross-host acceptance test must wait.
2. The confirmed Kria wired static address is `192.168.7.75/24`. Reconfirm it
   on the Kria at test time rather than relying only on this record.
3. `eth0` and `wlan0` are simultaneously on the same `192.168.7.0/24` LAN.
   Their IP addresses do not conflict. Linux currently prefers Jetson `eth0`
   because its route metric is 100 versus Wi-Fi's 600. DDS may still bind to
   both multicast-capable interfaces, so retain this as a diagnostic
   observation, not a reason to disable Wi-Fi before the first test.
4. Firewall state could not be fully read without root. Do not permanently
   disable a firewall. Inspect it with `sudo` immediately before the network
   test and make only a temporary, documented allowance if packet capture
   proves it necessary.
5. DDS discovery normally uses UDP multicast. Switches, access controls,
   VLANs, VPNs, containers, and host firewalls can interfere even when ping
   works.
6. A topic can be discovered while data is incompatible or dropped because of
   QoS. Record `ros2 topic info --verbose` before changing QoS assumptions.

## Confirmed phase 1 network map

```text
Jetson eth0:       192.168.7.68/24  static, wired
Jetson wlan0:      192.168.7.140/24 DHCP at audit time, Wi-Fi
Kria wired:        192.168.7.75/24  static
Mac Wi-Fi:         192.168.7.133
Mac other/wired:   192.168.7.31
```

All listed addresses are unique. The expected Jetson-to-Kria route is:

```text
192.168.7.68 (eth0) -> 192.168.7.75 (Kria wired)
```

## Scope exclusions

Do not install or build any of the following in phase 1:

- `metavision_driver`
- OpenEB
- `event_camera_msgs`
- RVT
- custom Event messages
- camera SDKs or camera nodes

Do not modify the Kria system, FPGA overlay, Active Marker, or permanent
network/firewall configuration.

## Acceptance criteria

Jetson installation passes when:

- `ROS_DISTRO=humble`
- `ROS_DOMAIN_ID=42`
- `RMW_IMPLEMENTATION=rmw_fastrtps_cpp`
- `ROS_LOCALHOST_ONLY=0`
- `ros2 doctor --report` completes
- `ros2 pkg prefix rclcpp` resolves under `/opt/ros/humble`
- `ros2 pkg prefix rmw_fastrtps_cpp` resolves under `/opt/ros/humble`

Cross-host phase 1 passes only when the Jetson, over wired Ethernet, discovers
`/kria/heartbeat`, receives messages with `ros2 topic echo`, and measures a
rate close to the Kria publisher's configured 10 Hz.
