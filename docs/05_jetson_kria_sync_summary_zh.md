# Jetson-Kria ROS2 工作同步摘要

日期：2026-08-13

## 当前结论

Kria 到 Jetson 的 ROS2 EVT21 原始事件传输已经实现，并完成了有界端到端
测试和两次有效的 5 分钟稳定性测试。Jetson 可以接收
`event_camera_msgs/msg/EventPacket`。EVT21 解码层已作为独立 Jetson C++ 包
加入 workspace；RVT adapter 和检测结果发布仍待接入。

## 两端固定接口

```text
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ROS_LOCALHOST_ONLY=0
Topic: /metavision_driver/events
Type: event_camera_msgs/msg/EventPacket
QoS: BEST_EFFORT / VOLATILE
Encoding: evt21;height=720;width=1280
Geometry: 1280 x 720
```

两端使用同一份 `event_camera_msgs 1.1.2` 源码。`EventPacket.msg` 的 SHA-256
为：

```text
14ddc08546652be8f3be45e49bde9fe499d6c673668c327e9ae53900d2584055
```

不要在 Kria 和 Jetson 之间复制 `build/`、`install/` 或隔离运行库；两端
操作系统和 ABI 不同，应分别构建。

## 已完成的证据

- Jetson Ubuntu 22.04 ARM64 已安装 ROS2 Humble、Fast DDS、colcon 和 C++ 工具。
- 本机 Fast DDS 约 10 Hz，通过。
- Kria heartbeat 到 Jetson 约 9.999 Hz，通过。
- IMX636 EVT21 原始流跨机传输通过。
- 15 秒测试约 808 包、53.810 MiB/s、观察到 0 个 sequence gap。
- 旧版本正式配置进行了三次 5 分钟测试：两次有效流内存稳定、时间戳无回退；
  分别观察到 8 和 4 个 sequence gaps；一次 publisher 可见但收到 0 包。
- 相机输入曾达到约 139 MiB/s，1 GbE 无法保证全速原始数据无损传输。

以上 5 分钟结果对应旧版本构建产物
`/data/builds/ROS2/metavision_driver_20260806_070856`，不能作为新有限队列
版本的实测证据。

## 当前 Kria 版本

当前源码已加入有限输入队列和丢弃统计：

```yaml
use_multithreading: true
input_queue_size: 4
send_queue_size: 4
event_message_size_threshold: 262144
```

队列满时丢弃新的原始块，并在周期日志中报告 `maxq`、`dropped` 和丢弃带宽；
停止节点时会释放队列中剩余的数据。新版本已交叉编译为 ARM64，产物为：

```text
/data/builds/ROS2/metavision_driver_20260813_011943/install/metavision_driver
```

新版本仍需在 Kria 上重新完成 5 分钟测试，不能直接复用旧版本的稳定性结论。

## Jetson C++ 接收节点

新增包：`src/jetson_event_receiver/`

节点 `event_packet_receiver` 订阅事件 topic，并报告：

- 包速率和有效载荷带宽；
- sequence gaps；
- header timestamp 回退；
- 非 EVT21 编码；
- 无数据持续时间。

Jetson 上构建和运行：

```bash
colcon build --packages-select event_camera_msgs jetson_event_receiver
source install/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_LOCALHOST_ONLY=0
ros2 run jetson_event_receiver event_packet_receiver
```

该节点目前只负责传输监控，不解码 EVT21，也不替代后续 RVT adapter。

## Jetson EVT21 解码节点

新增包：`src/jetson_evt21_decoder/`

`evt21_decoder_node` 订阅原始 `/metavision_driver/events`，解码 EVT21 向量
事件并发布：

```text
/metavision_driver/events_decoded
jetson_evt21_decoder/msg/DecodedEventPacket
```

消息包含每个事件的 `x`、`y`、相机时间戳 `t` 和 polarity。该包只负责解码，
不依赖 Python，也不运行 RVT；它的输出是后续 RVT adapter 的输入边界。

Jetson 上构建：

```bash
colcon build --packages-select event_camera_msgs jetson_evt21_decoder
source install/setup.bash
ros2 run jetson_evt21_decoder evt21_decoder_node
```

## 运行边界

- Active Marker、`metavision_viewer` 和 ROS driver 只能有一个进程占用相机。
- 停止 ROS driver 并确认释放设备后，才能恢复 Active Marker。
- Jetson 的 `install/` 必须在 Jetson 上重新生成，不能复制 Kria 的 ARM64
  PetaLinux overlay。

## 下一步

1. 用新有限队列版本在 Kria 上完成 300 秒测试。
2. 记录丢弃计数、DDS gaps、RSS、CPU 和两端网卡计数。
3. 根据结果选择 ERC、事件过滤或更低输出率，避免把 1 GbE 当作 139 MiB/s
   原始输入的无损链路。
4. 在 Jetson 运行 EVT21 decoder，并用解码 topic 做数据正确性检查。
5. 将 `DecodedEventPacket` 接入 RVT live inference。
6. 发布检测结果和可视化 ROS2 topics。
