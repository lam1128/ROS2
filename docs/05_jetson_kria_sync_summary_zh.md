# Jetson-Kria ROS2 工作同步摘要

日期：2026-08-13（汇总 2026-08-06 的安装与测试）

## 1. 系统与网络

Jetson：

```text
设备：NVIDIA Jetson AGX Orin Developer Kit
系统：Ubuntu 22.04.5 ARM64 / L4T R36.3
有线地址：192.168.7.68/24（eth0）
Wi-Fi 地址（审计时）：192.168.7.140/24
```

Kria：

```text
设备：KV260
系统：PetaLinux 2022.2 ARM64
有线地址：192.168.7.75/24（eth0）
```

统一 ROS2/DDS 配置：

```text
ROS_DISTRO=humble
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ROS_LOCALHOST_ONLY=0
```

Jetson 到 Kria 的路由已经确认使用 `eth0`，ICMP 测试 0% 丢包。

## 2. Jetson 已完成工作

Jetson 已安装：

```text
ros2-apt-source 1.2.0~jammy
ros-humble-ros-base 0.10.0
ros-humble-rmw-fastrtps-cpp 6.2.10
python3-colcon-common-extensions
build-essential
cmake
```

本机 Fast DDS 发布/订阅测试通过，10 Hz topic 实测约 10.000 Hz。

从 Kria 工作区复制了同一版本的 `event_camera_msgs 1.1.2` 源码，在
Jetson 重新构建了 C、C++、Fast DDS 和 Python typesupport。Jetson 因此
可以反序列化 `event_camera_msgs/msg/EventPacket`；没有安装
`metavision_driver`、OpenEB、RVT 或相机驱动。

## 3. 已通过的跨机测试

Heartbeat：

```text
Topic：/kria/heartbeat
Type：std_msgs/msg/String
QoS：RELIABLE / VOLATILE
频率：约 9.999 Hz
结果：PASS
```

15 秒实时事件流：

```text
链路：IMX636 -> KV260/OpenEB -> metavision_driver -> Fast DDS -> Jetson
Topic：/metavision_driver/events
Type：event_camera_msgs/msg/EventPacket
QoS：BEST_EFFORT / VOLATILE
编码：evt21;height=720;width=1280
尺寸：1280 x 720
包数：808
包率：53.810 Hz
负载：53.810 MiB/s
序号：3 至 810
观察到的 sequence gaps：0
结果：有界链路测试 PASS
```

这只证明 EVT21 原始字节传输成功。Jetson 当前没有 EVT21 decoder，不能
把 payload 解码成 `x/y/t/p` 事件。

## 4. 五分钟稳定性结果

正式 Kria 产物：

```text
/data/builds/ROS2/metavision_driver_20260806_070856/install/metavision_driver
```

正式配置使用 `use_multithreading: false`，避免早期版本的无界内部队列。

```text
尝试 1：300.008 s，16326 包，54.419 MiB/s，8 gaps，时间戳回退 0，RSS 稳定约 77424 KiB
尝试 2：300.213 s，0 包；publisher 可发现但没有有效流
尝试 3：300.007 s，16276 包，54.252 MiB/s，4 gaps，时间戳回退 0，RSS 稳定约 77308 KiB
```

结论：

- 5 分钟内存稳定性在两次有效流中通过；
- header timestamp 单调性通过；
- BEST_EFFORT 发布序号存在少量缺口，零缺口要求未通过；
- 有一次零数据运行，重复性尚未通过；
- 相机输入曾测得约 139 MiB/s，1 GbE 无法无损承载该速率加 DDS/UDP/IP 开销；
- 长期全速无损传输尚未证明。

## 5. Jetson 手工维护文件及用途

### 根目录和环境

- `/home/anavs/ROS2/README.md`：工作区入口、当前状态和文件导航。
- `/home/anavs/ROS2/config/jetson_ros2_env.sh`：一次性加载 Humble、Jetson
  `event_camera_msgs` overlay，并设置 domain 42、Fast DDS 和跨主机发现。

### 文档

- `docs/01_feasibility.md`：Jetson 系统、架构、网络和安装可行性审计。
- `docs/02_runbook.md`：Humble 安装、网络检查和 heartbeat 验收流程。
- `docs/03_test_record.md`：第一阶段 heartbeat 的正式测试记录。
- `docs/04_event_stream_test.md`：IMX636 EVT21 事件流、吞吐量和稳定性结论。
- `docs/05_jetson_kria_sync_summary_zh.md`：本同步摘要。

### 脚本

- `scripts/00_readonly_audit.sh`：只读采集系统、ROS、网卡、路由、磁盘和时钟信息。
- `scripts/10_install_humble.sh`：受保护的 Humble 安装器；默认 dry-run，只有
  `--apply` 且人工输入 `INSTALL` 才修改 APT。
- `scripts/20_verify_install.sh`：运行 `ros2 doctor` 并检查 `rclcpp`、Fast DDS 前缀。
- `scripts/25_local_smoke_test.sh`：Jetson 本机 10 Hz Fast DDS 发布/订阅测试。
- `scripts/30_test_kria_heartbeat.sh`：检查 eth0 路由、ping、heartbeat 类型、消息和频率。
- `scripts/35_test_event_stream.sh`：15 秒事件流测试，检查 topic、QoS、包率、负载和序号。
- `scripts/36_stability_event_stream.sh`：默认 300 秒稳定性测试，记录包率、带宽、
  sequence gaps、时间戳、Kria RSS 和两端网卡计数。

### 消息包和生成目录

- `src/event_camera_msgs/`：与 Kria 同源的 1.1.2 消息源码；关键定义为
  `msg_ros2/EventPacket.msg`。
- `build/event_camera_msgs/`：Jetson colcon/CMake 中间产物，可重新生成，不应同步到 Kria。
- `install/event_camera_msgs/`：Jetson ARM64 Ubuntu typesupport overlay，不应复制到 Kria。
- `install/setup.bash`：colcon 生成的 Jetson overlay 入口，由环境脚本自动加载。
- `log/`：colcon 构建日志。
- `logs/`：系统审计及运行测试证据。

### 历史兼容补丁

- `patches/metavision_driver_evt21_passthrough.patch`：第一次验证 EVT21 raw transport
  时使用的临时兼容补丁。Kria 后来已将 EVT21 支持正式加入源码，因此此文件仅作
  历史/审计记录，不应覆盖 Kria 当前源码。

## 6. Kria 正式维护文件及用途

- `src/metavision_driver/config/kria_imx636_evt21.yaml`：IMX636 EVT21 参数、1 MiB
  batching、BEST_EFFORT publisher queue depth 1、单线程采集路径。
- `src/metavision_driver/launch/kria_imx636_evt21.launch.py`：Kria live driver launch。
- `scripts/runtime/kria_ros2_live_env.sh`：选择最新隔离 driver/message 产物并配置
  ROS、Fast DDS、OpenEB、sysroot 和 V4L2 环境。
- `docs/live_stream_status.md`：Kria 侧实时流状态、启动流程和剩余风险。
- `metavision_driver_20260806_070856/install/metavision_driver`：当前正式 Kria 构建产物。

## 7. 同步边界

不要在 Jetson 与 Kria 之间复制 `build/` 或 `install/` 二进制目录：Jetson 是
Ubuntu Jammy ARM64，Kria 是 PetaLinux，二者 ABI 和 Python 版本不同。

两端应该同步/核对：

1. `EventPacket.msg` 字段和版本；
2. `ROS_DOMAIN_ID=42`、`rmw_fastrtps_cpp`、`ROS_LOCALHOST_ONLY=0`；
3. `/metavision_driver/events`、`event_camera_msgs/msg/EventPacket`；
4. EVT21 完整编码字符串与 1280x720 geometry；
5. QoS 为 BEST_EFFORT / VOLATILE；
6. 测试日志中的 sequence gap、timestamp、RSS 与网卡计数。

## 8. 下一步建议

1. 用修正后的 Jetson `scripts/36_stability_event_stream.sh 300` 再运行一次，取得
   完整的前后网卡计数；脚本现在即使发现 gap 也会保存结束证据。
2. 在 Kria driver 内加入明确的相机输入块计数、发布计数、丢弃计数和队列/背压计数。
3. 判断 4-8 个 sequence gaps 是 DDS/网卡丢包还是发布端行为。
4. 为长期运行选择限流方案，例如 IMX636 ERC、事件过滤或更低输出率；1 GbE 不应
   被视为可无损承载 139 MiB/s 原始输入。
5. 保持相机独占：Active Marker、`metavision_viewer` 和 ROS driver 只能运行一个。
6. 在停止 ROS driver 并确认释放设备后，才恢复 Active Marker。
