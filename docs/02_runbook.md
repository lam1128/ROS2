# Jetson-to-Kria ROS 2 phase 1 runbook

Run commands on the Jetson unless a section explicitly says **Kria**. Stop at
each gate and save the output. Do not run the install step until it has been
reviewed and approved.

## Phase A: pre-install audit (safe to run now)

```bash
cd /home/anavs/ROS2
./scripts/00_readonly_audit.sh | tee logs/00_audit_$(date +%F_%H%M%S).log
./scripts/10_install_humble.sh
```

The second command is a dry run. It prints package and repository changes.

Stop if the audit no longer reports Ubuntu 22.04 (`jammy`) and ARM64
(`arm64`/`aarch64`). Do not substitute another ROS distribution.

## Phase B: install Humble on Jetson

After approval:

```bash
cd /home/anavs/ROS2
./scripts/10_install_humble.sh --apply \
  |& tee logs/10_install_$(date +%F_%H%M%S).log
```

The script:

1. verifies Jammy and ARM64;
2. installs the official `ros2-apt-source` repository package;
3. updates APT indexes;
4. installs only ROS base, Fast DDS RMW, colcon, and C++ build essentials.

It deliberately does not run `apt upgrade`, add shell startup changes, or
install camera/event packages. Review any APT dependency/removal proposal
before accepting it. Abort if APT proposes removing NVIDIA Jetson packages.

## Phase C: verify the local installation

Use a clean shell:

```bash
cd /home/anavs/ROS2
source config/jetson_ros2_env.sh
ros2 daemon stop
./scripts/20_verify_install.sh \
  |& tee logs/20_verify_$(date +%F_%H%M%S).log
./scripts/25_local_smoke_test.sh \
  |& tee logs/25_local_smoke_$(date +%F_%H%M%S).log
```

Expected environment:

```text
ROS_DISTRO=humble
ROS_DOMAIN_ID=42
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ROS_LOCALHOST_ONLY=0
```

Do not add the environment file to `.bashrc` yet. Explicit sourcing makes the
first test reproducible and avoids affecting unrelated ROS work.

The local smoke test uses the standard `std_msgs/msg/String` type on the
temporary `/jetson/ros2_smoke` topic. It does not create a package, message
definition, service, or persistent node.

## Phase D: prepare both ends for wired Ethernet

Wait until the Kria Humble runtime and heartbeat node are ready. The recorded
Kria wired static address is `192.168.7.75/24`; still verify it on the Kria at
test time:

On **Kria**, record rather than guess its address:

```bash
ip -brief address
ip route
```

On the **Jetson**, confirm the route to the recorded address uses Ethernet:

```bash
KRIA_IP=192.168.7.75
ip -brief address show eth0
ip route get "$KRIA_IP"
ping -I eth0 -c 4 "$KRIA_IP"
```

The `ip route get` output must say `dev eth0` and use the intended Jetson
source address `192.168.7.68`. A successful ping is necessary but does not
prove DDS works.

Jetson Wi-Fi may remain connected for the first test. Its address is unique,
and the lower Ethernet route metric should select `eth0` for Kria unicast
traffic. Do not disconnect Wi-Fi unless route output or DDS evidence shows an
interface-selection problem.

On both machines, use exactly:

```bash
source /opt/ros/humble/setup.bash
export ROS_DOMAIN_ID=42
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_LOCALHOST_ONLY=0
ros2 daemon stop
```

Confirm there is no VPN or container namespace involved in either ROS process.
Do not change Kria networking.

## Phase E: inspect firewall without changing it

On Jetson:

```bash
sudo ufw status verbose 2>/dev/null || true
sudo nft list ruleset
```

Save the output. Do not permanently disable the firewall. If a firewall is
active, first attempt the test while capturing traffic. Any temporary rule
must be based on the actual wired subnet and removed after the test.

Fast DDS ports depend on domain and participant IDs, so a narrow guessed port
rule can be unreliable. Prefer a time-limited UDP allowance restricted to the
wired test subnet only after review. Do not open UDP globally.

## Phase F: start publisher and test from Jetson

On **Kria**, the short three-variable command is not sufficient on the current
PetaLinux image: it fails because the extracted Ubuntu Humble runtime requires
Python 3.10, newer libstdc++, spdlog, OpenSSL, and other compatibility
libraries. Start the already-built publisher with the existing isolated
runtime paths:

```bash
ROOT=/data/tools/kria-build-root
ROS=/data/tools/ros2-humble-20231122/ros2-linux

export LD_LIBRARY_PATH="$ROOT/usr/lib:$ROOT/usr/lib/aarch64-linux-gnu:$ROOT/lib:$ROOT/lib/aarch64-linux-gnu:$ROS/lib"
export AMENT_PREFIX_PATH="$ROS"
export ROS_DISTRO=humble
export ROS_VERSION=2
export ROS_PYTHON_VERSION=3
export ROS_DOMAIN_ID=42
export ROS_LOCALHOST_ONLY=0
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp

/data/builds/ROS2/kria_event_bridge_direct15/kria_heartbeat_publisher
```

These values affect only that process. Do not copy the compatibility libraries
into `/usr` or treat this as a native PetaLinux ROS 2 deployment.

On **Jetson**:

```bash
cd /home/anavs/ROS2
source config/jetson_ros2_env.sh
ros2 daemon stop
./scripts/30_test_kria_heartbeat.sh KRIA_IP \
  |& tee logs/30_heartbeat_$(date +%F_%H%M%S).log
```

For the currently recorded topology, the command is:

```bash
./scripts/30_test_kria_heartbeat.sh 192.168.7.75 \
  |& tee logs/30_heartbeat_$(date +%F_%H%M%S).log
```

The script checks the route and ping, waits for topic discovery, records type
and QoS details, receives one message, then samples topic rate for
15 seconds. It does not modify networking or the firewall.

## Phase G: diagnose only if discovery fails

1. Reconfirm all four ROS environment values on both hosts.
2. Run `ros2 daemon stop` on both hosts after every environment change.
3. Confirm `ip route get KRIA_IP` uses Jetson `eth0`.
4. Check that both clocks are synchronized.
5. Capture discovery traffic on Jetson:

   ```bash
   sudo timeout 20 tcpdump -ni eth0 udp \
     -w /home/anavs/ROS2/logs/dds_eth0_$(date +%F_%H%M%S).pcap
   ```

6. Only if multi-interface selection is implicated, obtain approval for one
   reversible experiment: temporarily disconnect Jetson Wi-Fi and repeat.
   Re-enable it immediately afterward. Do not change Kria interfaces.
7. Only if firewall drops are demonstrated, add a temporary subnet-scoped
   allowance, retest, remove it, and record all three commands.
8. If discovery works but `echo` does not, compare the publisher/subscriber
   topic type and QoS using `ros2 topic info --verbose`.

Do not respond to a failure by installing another ROS distribution or any
camera/event stack.

## Phase H: record outcome

Fill in `docs/03_test_record.md` with both IP addresses, interface names,
environment output, package prefixes, topic type/QoS, observed rate, and log
paths. Phase 1 is complete only after `echo` and `hz` succeed across Ethernet.

## Official references

- [ROS 2 Humble Ubuntu Debian installation](https://docs.ros.org/en/humble/Installation/Ubuntu-Install-Debs.html)
- [Selecting and changing an RMW implementation](https://docs.ros.org/en/humble/How-To-Guides/Working-with-multiple-RMW-implementations.html)
- [ROS 2 Domain ID](https://docs.ros.org/en/humble/Concepts/Intermediate/About-Domain-ID.html)
- [Official ROS APT source releases](https://github.com/ros-infrastructure/ros-apt-source/releases)
