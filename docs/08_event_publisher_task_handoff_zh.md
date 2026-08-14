# Kria ROS2 Event Publisher 项目交接

本文件保存当前任务总结、已完成工作和后续计划。

> 任务优先级：Jetson 上已有的 `/home/anavs/jetson-containers/data/RVT` 是之前其他工作的 RVT 工程，当前可以忽略。后续以用户提供的任务单“ROS2 Publisher für Events auf Kria implementieren”为唯一优先级。

## 1. 用户任务

Kria：尝试使用 ROS2；实现 Event Publisher；通过 Ethernet 将事件消息发送到 Jetson；如果 ROS2 不可行，才考虑 C++/TCP EventPacket。

Jetson：可选实现 Event Slicing；按任务需要将 RVT 适配为 Live Inference；发布检测结果和可视化 ROS2 topics。

工作顺序：先完成 Kria ROS2 publisher 和 Kria → Jetson 传输；然后完成 Jetson 侧 RVT Live Inference、检测结果和可视化 topic。Event Slicing 是可选项，放在必需功能之后。TCP 仅作为 ROS2 publisher 失败时的 fallback。

## 2. 设备与环境

Kria：KV260、PetaLinux 2022.2、ARM64、Python 3.9、地址 `192.168.7.75`、workspace `/data/workspaces/ROS2`。

Jetson：Ubuntu ARM64、地址 `192.168.7.68`、用户 `anavs`、workspace `/home/anavs/ROS2`。

Kria 不是普通 Ubuntu。ROS2 Python 部分按 Python 3.10 构建，而系统是 Python 3.9，因此不要依赖 `rclpy`、`ros2 launch`、Python launch 或 ROS2 Python CLI。Kria 核心功能使用 C++，通过 Bash 设置环境并直接运行 C++ executable。

Kria 运行：

```bash
cd /data/workspaces/ROS2
source scripts/runtime/kria_ros2_live_env.sh
bash scripts/runtime/run_kria_evt21_driver.sh
```

Kria 构建隔离目录：`/data/tools/`、`/data/builds/ROS2/`、`/data/workspaces/ROS2/`。Kria → Jetson 免密 SSH 已验证成功，私钥为 `/home/root/.ssh/id_ed25519_jetson_ros2`。

## 3. 固定 ROS2 配置与链路

```text
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ROS_LOCALHOST_ONLY=0
```

链路：

```text
IMX636 → Kria Metavision/OpenEB → C++ metavision_driver
→ /metavision_driver/events → Fast DDS/Ethernet → Jetson receiver
```

消息类型：`event_camera_msgs/msg/EventPacket`；编码：`evt21;height=720;width=1280`；QoS：BEST_EFFORT + VOLATILE。

两端 `EventPacket.msg` SHA-256 已确认一致：

```text
14ddc08546652be8f3be45e49bde9fe499d6c673668c327e9ae53900d2584055
```

## 4. 已完成工作

### Kria publisher

已使用 `metavision_driver` 作为 C++ ROS2 Event Publisher，绕过 Python launch。

配置文件：`/data/workspaces/ROS2/src/metavision_driver/config/kria_imx636_evt21.yaml`。

关键配置：`encoding=evt21;height=720;width=1280`、`use_multithreading=true`、`input_queue_size=4`、`send_queue_size=4`、`event_message_time_threshold=0.001`、`event_message_size_threshold=262144`、`erc_mode=enabled`、`erc_rate=5000000`。

构建命令：

```bash
cd /data/workspaces/ROS2
bash scripts/build/build_metavision_driver_isolated.sh
```

最近一次成功产物：`/data/builds/ROS2/metavision_driver_20260813_045833/install`。相机已成功加载并启动，设备包括 `/dev/video0`、`/dev/media0`、`/dev/v4l-subdev3`。

### Jetson receiver 与 decoder

已有包：`src/event_camera_msgs/`、`src/jetson_event_receiver/`、`src/jetson_evt21_decoder/`。

```bash
cd /home/anavs/ROS2
colcon build --packages-select event_camera_msgs jetson_event_receiver jetson_evt21_decoder
```

链路：`/metavision_driver/events` → `jetson_evt21_decoder` → `/metavision_driver/events_decoded`。

实际验证：三个包成功构建；原始 EVT21 可收到；decoder 可发布解码 topic；receiver 约 27–28 MiB/s；当时 `sequence gaps=0`、`timestamp regressions=0`、`unexpected_encoding=0`。

## 5. 已知限制

IMX636 原始输入约 139.5 MiB/s，约 1.16 Gb/s，超过当前 1GbE 实际承载能力。接收端运行时曾观测 Kria 输入约 139.5 MiB/s、输出约 27–28 MiB/s、dropped 约 223–224/2 秒。

有限队列只能防止内存无限增长、保持 RSS 稳定并提供 dropped 统计，不能解决带宽不足。

ERC 配置虽为 `enabled` / `5000000`，但启动日志为 `cannot set event rate control for this camera!`。trail filter 测试也显示 `this camera does not support trail filtering!`。因此当前 KV260/PetaLinux/V4L2/IMX636 EVT21 路径中，ERC 和 trail filter 没有实际生效，不能描述为硬件限流成功。

## 6. 后续任务（按任务单重新排序）

### 优先级 1：完成任务的核心链路

确认并整理以下必需交付：

```text
Kria ROS2 publisher
→ ROS2 messages over Ethernet
→ Jetson receiver
→ RVT Live Inference wrapper
→ detection ROS2 topic
→ visualization ROS2 topic
```

ROS2 已经能够在 Kria 上以 C++ 方式运行，因此当前不实现 TCP fallback。只有在 ROS2 publisher 或 ROS2 Ethernet transport 被证明不可用时，才重新评估 C++/TCP 方案。

### 优先级 2：解决传输的可用性和带宽问题

先调查当前 Metavision HAL/V4L2 路径是否存在其他硬件事件率控制接口；确认没有后，实现 Kria C++ 软件传输限流，并明确丢弃策略、计数和日志。候选结构是：相机原始输入 → 可选的 Kria 本地完整保存；同时将软件限流后的 EventPacket 发送到 Jetson。

验收记录：发送带宽、dropped、sequence gaps、RSS。不能宣称完整 139.5 MiB/s 原始流通过 1GbE 实时无损传输。

当前实现进展：已在 `metavision_driver` 的 raw callback、进入输入队列之前加入可关闭的字节令牌桶。配置参数为 `software_rate_limit_bytes_per_sec` 和 `software_rate_limit_burst_bytes`；当前 Kria 初始配置为 `25000000` bytes/s、`4194304` bytes burst。限流单位是原始字节，按完整 raw block 接收或丢弃，不截断 EVT21。周期日志区分 SDK 输入队列丢弃和软件限流丢弃，并记录各自的 block/字节统计。短时设备测试已确认限流计数生效；尚未完成与 Jetson receiver 联动的参数标定和 300 秒实测。

### 优先级 3：RVT Live Inference、检测和可视化

旧的 `/home/anavs/jetson-containers/data/RVT` 不作为当前项目基线。只有任务明确需要并确认模型资料后，才确定模型、checkpoint、事件表示、输入分辨率、检测消息和可视化 topic。

模型资料已确认：Jetson 原有 `/home/anavs/jetson-containers/data/checkpoints/rvt/rvt-t-gen1.ckpt` 是 Gen1 权重，不匹配当前 1280x720/1 Mpx 输入。已下载官方 1 Mpx（Gen4）Tiny 权重到 `/home/anavs/jetson-containers/data/RVT/checkpoints/rvt-t-gen4.ckpt`，文件约 68 MB，MD5 为 `5a3c7893280d23ab5d22d17dffeb818b`（与官方 README 的 `5a3c78` 前缀一致）。后续 ROS2 wrapper 从该 RVT 工程内路径加载。

已创建 `/home/anavs/ROS2/src/rvt_live_inference`。第一版订阅 `/metavision_driver/events_decoded`，按 50 ms 窗口生成 10-bin stacked histogram（20 channels），下采样到 360x640，加载 RVT-Tiny 并保持 recurrent state；检测发布到 `/rvt/detections`（JSON `std_msgs/String`），事件可视化发布到 `/rvt/visualization`（`sensor_msgs/Image`）。Jetson 上已构建成功，并在 `rvt:jetson` 容器中完成 checkpoint 和 ROS2 节点启动验证；尚未进行真实 EVT21 事件输入下的端到端推理性能测试。当前容器启动需要挂载主机 ROS2 Humble 库和 ROS2 workspace，后续应整理成固定运行脚本。

### 优先级 4：300 秒稳定性测试

记录 Kria 输入/输出带宽、dropped、maxq、RSS、相机错误；Jetson 接收带宽、packet rate、sequence gaps、timestamp regressions、RSS；decoder 解码速率、事件数量和 malformed packets；后续推理的速率、延迟、GPU/CPU 内存和检测发布率。

### 优先级 5：Event Slicing（可选）

Event Slicing 在原任务中明确标记为 optional，不是当前验收的必需项。只有当 RVT 的 live 输入接口需要独立切片，或测试证明必须拆分事件窗口时，才实现它。第一版优先在 RVT wrapper 内部按时间窗口处理，不单独增加 slicer 节点。

## 7. 同步规则

推荐 Mac ↔ Jetson 使用 Git，Mac → Kria 使用 tar + ssh。

规则：修改前先同步；一次只在一端修改源码；修改后在该端构建和测试；测试通过后提交或打包同步；另一端重新构建；不复制 `.git/`、`build/`、`install/`、`log/`、`logs/`。

当前状态：Kria 的 `kria_imx636_evt21.yaml` 有 ERC 配置修改，尚未同步到 Mac/GitHub；Jetson receiver 和 decoder 源码已存在并成功构建；没有新增 RVT adapter 源码。

## 8. 当前结论

已完成：Kria C++ ROS2 publisher → ROS2/Fast DDS Ethernet transport → Jetson receiver → EVT21 decoder。

尚未完成：设备上的软件限流实测与参数标定、按任务要求的 RVT Live Inference、Detection topics、Visualization topics、300 秒完整稳定性测试。Event Slicing 属于可选后续项；TCP fallback 当前不需要实现。

> 准确交付表述：在 KV260/PetaLinux 环境下，已使用 C++ ROS2 publisher 将 IMX636 EVT21 原始事件通过 Fast DDS 发送到 Jetson，并完成 Jetson 侧接收和 EVT21 解码验证。当前 V4L2 IMX636 路径不提供可用 ERC 或 trail filter，原始事件率约 139.5 MiB/s，超过 1GbE 实时无损传输能力。后续需根据任务需要实现可验证的软件或硬件事件率控制，再决定 Event Slicing 和 Live Inference 的具体适配范围。
