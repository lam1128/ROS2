#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TOPIC="${1:-/metavision_driver/events}"
source "${ROOT_DIR}/config/jetson_ros2_env.sh"

echo "== Environment =="
printenv | grep -E \
  '^(ROS_DISTRO|ROS_DOMAIN_ID|RMW_IMPLEMENTATION|ROS_LOCALHOST_ONLY)=' \
  | sort

echo
echo "== Wait for ${TOPIC} =="
ros2 daemon stop >/dev/null 2>&1 || true
FOUND=0
for _ in $(seq 1 30); do
  if ros2 topic list 2>/dev/null | grep -Fxq "${TOPIC}"; then
    FOUND=1
    break
  fi
  sleep 1
done
if [[ "${FOUND}" -ne 1 ]]; then
  echo "FAIL: ${TOPIC} was not discovered within 30 seconds." >&2
  exit 2
fi

echo
echo "== Topic endpoint and QoS =="
ros2 topic info --verbose "${TOPIC}"
TYPE="$(ros2 topic type "${TOPIC}")"
if [[ "${TYPE}" != "event_camera_msgs/msg/EventPacket" ]]; then
  echo "FAIL: expected event_camera_msgs/msg/EventPacket, got ${TYPE}." >&2
  exit 3
fi

echo
echo "== Receive one packet (event byte array hidden) =="
timeout 15 ros2 topic echo "${TOPIC}" "${TYPE}" \
  --qos-reliability best_effort --no-arr --once

echo
echo "== Measure 15-second stream =="
EVENT_TOPIC="${TOPIC}" python3 - <<'PY'
import os
import sys
import time

import rclpy
from event_camera_msgs.msg import EventPacket
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy


class EventMonitor(Node):
    def __init__(self, topic):
        super().__init__("jetson_event_stream_monitor")
        qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=32,
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
        )
        self.packets = 0
        self.payload_bytes = 0
        self.sequence_gaps = 0
        self.first_seq = None
        self.last_seq = None
        self.width = 0
        self.height = 0
        self.encoding = ""
        self.create_subscription(EventPacket, topic, self.on_packet, qos)

    def on_packet(self, msg):
        if self.last_seq is not None and msg.seq > self.last_seq + 1:
            self.sequence_gaps += msg.seq - self.last_seq - 1
        if self.first_seq is None:
            self.first_seq = msg.seq
        self.last_seq = msg.seq
        self.packets += 1
        self.payload_bytes += len(msg.events)
        self.width = msg.width
        self.height = msg.height
        self.encoding = msg.encoding


rclpy.init()
node = EventMonitor(os.environ["EVENT_TOPIC"])
start = time.monotonic()
duration = 15.0
try:
    while rclpy.ok() and time.monotonic() - start < duration:
        rclpy.spin_once(node, timeout_sec=0.25)
finally:
    elapsed = time.monotonic() - start
    node.destroy_node()
    rclpy.shutdown()

packet_rate = node.packets / elapsed
byte_rate = node.payload_bytes / elapsed
print(f"packets={node.packets}")
print(f"packet_rate_hz={packet_rate:.3f}")
print(f"payload_bytes={node.payload_bytes}")
print(f"payload_rate_mib_s={byte_rate / (1024 * 1024):.3f}")
print(f"first_seq={node.first_seq} last_seq={node.last_seq}")
print(f"sequence_gaps={node.sequence_gaps}")
print(f"geometry={node.width}x{node.height}")
print(f"encoding={node.encoding}")

if node.packets == 0 or node.payload_bytes == 0 or packet_rate <= 0:
    print("FAIL: event stream was discovered but no non-empty packets arrived.", file=sys.stderr)
    sys.exit(4)
PY

echo
echo "PASS: event topic discovery, type support, packet receipt, and rate test completed."
