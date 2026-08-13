# Jetson ROS 2 Humble phase 1

This directory contains the reviewed plan and guarded helper scripts for the
first Jetson-side ROS 2 communication test with the Kria.

No ROS package, firewall rule, network setting, camera package, FPGA overlay,
or Kria system was changed while preparing these files.

## Current decision

- Target: NVIDIA Jetson AGX Orin Developer Kit
- OS: Ubuntu 22.04.5 (Jammy)
- Architecture: ARM64 (`aarch64`)
- Jetson Linux: L4T R36.3
- Decision: ROS 2 Humble Debian packages are a supported match.
- Current ROS state: ROS 2 Humble base, Fast DDS RMW, and colcon installed and
  locally verified on 2026-08-06.
- Test topic: `/kria/heartbeat`
- Cross-host status: PASS on 2026-08-06 at approximately 9.999 Hz.
- Camera-to-Jetson raw event transport: PASS as a bounded 15-second EVT21
  compatibility test; sustained lossless full-rate transport is not yet proven.

Read these in order:

1. [Feasibility](docs/01_feasibility.md)
2. [Runbook](docs/02_runbook.md)
3. [Test record](docs/03_test_record.md)
4. [Event stream test](docs/04_event_stream_test.md)
5. [Jetson-Kria Chinese sync summary](docs/05_jetson_kria_sync_summary_zh.md)

Scripts are deliberately separated by phase:

```text
scripts/00_readonly_audit.sh
scripts/10_install_humble.sh
scripts/20_verify_install.sh
scripts/25_local_smoke_test.sh
scripts/30_test_kria_heartbeat.sh
scripts/35_test_event_stream.sh
scripts/36_stability_event_stream.sh
config/jetson_ros2_env.sh
```

`10_install_humble.sh` only prints the planned changes by default. It requires
the explicit `--apply` argument before it invokes `sudo` or changes APT state.
