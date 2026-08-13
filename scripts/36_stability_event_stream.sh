#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DURATION="${1:-300}"
TOPIC="${2:-/metavision_driver/events}"
KRIA_HOST="${KRIA_HOST:-petalinux@192.168.7.75}"

if ! [[ "${DURATION}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 [duration_seconds] [topic]" >&2
  exit 2
fi

source "${ROOT_DIR}/config/jetson_ros2_env.sh"

STAMP="$(date +%F_%H%M%S)"
LOG_DIR="${ROOT_DIR}/logs"
INFO_LOG="${LOG_DIR}/36_topic_info_${STAMP}.log"
MEMORY_LOG="${LOG_DIR}/36_kria_memory_${STAMP}.log"
COUNTER_BEFORE="${LOG_DIR}/36_net_before_${STAMP}.log"
COUNTER_AFTER="${LOG_DIR}/36_net_after_${STAMP}.log"
MONITOR_LOG="${LOG_DIR}/36_stability_${STAMP}.log"
MEMORY_PID=""

cleanup() {
  if [[ -n "${MEMORY_PID}" ]]; then
    kill "${MEMORY_PID}" 2>/dev/null || true
    wait "${MEMORY_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

network_snapshot() {
  local label="$1"
  local output="$2"
  {
    echo "label=${label}"
    echo "timestamp=$(date +%s)"
    for counter in rx_bytes rx_packets rx_dropped rx_errors \
      tx_bytes tx_packets tx_dropped tx_errors; do
      printf 'jetson_eth0_%s=' "${counter}"
      cat "/sys/class/net/eth0/statistics/${counter}"
    done
    ssh -o BatchMode=yes "${KRIA_HOST}" '
      for counter in rx_bytes rx_packets rx_dropped rx_errors \
        tx_bytes tx_packets tx_dropped tx_errors; do
        printf "kria_eth0_%s=" "${counter}"
        cat "/sys/class/net/eth0/statistics/${counter}"
      done
    '
  } >"${output}"
}

echo "== Environment =="
printenv | grep -E \
  '^(ROS_DISTRO|ROS_DOMAIN_ID|RMW_IMPLEMENTATION|ROS_LOCALHOST_ONLY)=' \
  | sort

echo
echo "== Wait for ${TOPIC} =="
ros2 daemon stop >/dev/null 2>&1 || true
FOUND=0
for _ in $(seq 1 60); do
  if ros2 topic list 2>/dev/null | grep -Fxq "${TOPIC}"; then
    FOUND=1
    break
  fi
  sleep 1
done
if [[ "${FOUND}" -ne 1 ]]; then
  echo "FAIL: ${TOPIC} was not discovered within 60 seconds." >&2
  exit 3
fi

ros2 topic info --verbose "${TOPIC}" | tee "${INFO_LOG}"
TYPE="$(ros2 topic type "${TOPIC}")"
if [[ "${TYPE}" != "event_camera_msgs/msg/EventPacket" ]]; then
  echo "FAIL: expected event_camera_msgs/msg/EventPacket, got ${TYPE}." >&2
  exit 4
fi

DRIVER_PID="$(
  ssh -o BatchMode=yes "${KRIA_HOST}" \
    'ps -eo pid,args | awk "/[m]etavision_driver.*driver_node/{print \$1; exit}"'
)"
if [[ -z "${DRIVER_PID}" ]]; then
  echo "FAIL: could not identify the Kria driver process." >&2
  exit 5
fi
echo "Kria driver PID: ${DRIVER_PID}"

network_snapshot before "${COUNTER_BEFORE}"

ssh -o BatchMode=yes "${KRIA_HOST}" "
  i=0
  while [ \"\${i}\" -le ${DURATION} ]; do
    printf 'timestamp=%s ' \"\$(date +%s)\"
    ps -o pid=,rss=,vsz=,stat= -p ${DRIVER_PID} 2>/dev/null || echo 'process_exited'
    i=\$((i + 5))
    [ \"\${i}\" -gt ${DURATION} ] || sleep 5
  done
" >"${MEMORY_LOG}" &
MEMORY_PID=$!

echo
echo "== Monitor ${DURATION} seconds =="
set +e
EVENT_TOPIC="${TOPIC}" TEST_DURATION="${DURATION}" python3 - <<'PY' \
  | tee "${MONITOR_LOG}"
import os
import sys
import time

import rclpy
from event_camera_msgs.msg import EventPacket
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy


class StabilityMonitor(Node):
    def __init__(self, topic):
        super().__init__("jetson_event_stability_monitor")
        qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=32,
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
        )
        self.packets = 0
        self.payload_bytes = 0
        self.sequence_gaps = 0
        self.reordered_sequences = 0
        self.first_seq = None
        self.last_seq = None
        self.first_stamp_ns = None
        self.last_stamp_ns = None
        self.timestamp_regressions = 0
        self.timestamp_duplicates = 0
        self.min_stamp_delta_ns = None
        self.max_stamp_delta_ns = 0
        self.width = 0
        self.height = 0
        self.encoding = ""
        self.create_subscription(EventPacket, topic, self.on_packet, qos)

    def on_packet(self, msg):
        if self.last_seq is not None:
            if msg.seq > self.last_seq + 1:
                self.sequence_gaps += msg.seq - self.last_seq - 1
            elif msg.seq <= self.last_seq:
                self.reordered_sequences += 1
        if self.first_seq is None:
            self.first_seq = msg.seq
        self.last_seq = msg.seq

        stamp_ns = msg.header.stamp.sec * 1_000_000_000 + msg.header.stamp.nanosec
        if self.last_stamp_ns is not None:
            delta = stamp_ns - self.last_stamp_ns
            if delta < 0:
                self.timestamp_regressions += 1
            elif delta == 0:
                self.timestamp_duplicates += 1
            else:
                if self.min_stamp_delta_ns is None or delta < self.min_stamp_delta_ns:
                    self.min_stamp_delta_ns = delta
                self.max_stamp_delta_ns = max(self.max_stamp_delta_ns, delta)
        if self.first_stamp_ns is None:
            self.first_stamp_ns = stamp_ns
        self.last_stamp_ns = stamp_ns

        self.packets += 1
        self.payload_bytes += len(msg.events)
        self.width = msg.width
        self.height = msg.height
        self.encoding = msg.encoding


duration = float(os.environ["TEST_DURATION"])
rclpy.init()
node = StabilityMonitor(os.environ["EVENT_TOPIC"])
start = time.monotonic()
try:
    while rclpy.ok() and time.monotonic() - start < duration:
        rclpy.spin_once(node, timeout_sec=0.25)
finally:
    elapsed = time.monotonic() - start
    node.destroy_node()
    rclpy.shutdown()

packet_rate = node.packets / elapsed
byte_rate = node.payload_bytes / elapsed
print(f"elapsed_s={elapsed:.3f}")
print(f"packets={node.packets}")
print(f"packet_rate_hz={packet_rate:.3f}")
print(f"payload_bytes={node.payload_bytes}")
print(f"payload_rate_mib_s={byte_rate / (1024 * 1024):.3f}")
print(f"first_seq={node.first_seq} last_seq={node.last_seq}")
print(f"sequence_gaps={node.sequence_gaps}")
print(f"reordered_sequences={node.reordered_sequences}")
print(f"first_stamp_ns={node.first_stamp_ns} last_stamp_ns={node.last_stamp_ns}")
print(f"timestamp_regressions={node.timestamp_regressions}")
print(f"timestamp_duplicates={node.timestamp_duplicates}")
print(f"min_stamp_delta_ns={node.min_stamp_delta_ns}")
print(f"max_stamp_delta_ns={node.max_stamp_delta_ns}")
print(f"geometry={node.width}x{node.height}")
print(f"encoding={node.encoding}")

if node.packets == 0 or node.payload_bytes == 0:
    print("FAIL: no non-empty event packets arrived.", file=sys.stderr)
    sys.exit(10)
if node.sequence_gaps or node.reordered_sequences or node.timestamp_regressions:
    print("FAIL: continuity errors were observed.", file=sys.stderr)
    sys.exit(11)
PY
MONITOR_STATUS=${PIPESTATUS[0]}
set -e

wait "${MEMORY_PID}" || true
MEMORY_PID=""
network_snapshot after "${COUNTER_AFTER}"

echo
echo "== Kria memory samples (KiB) =="
cat "${MEMORY_LOG}"

FIRST_RSS="$(awk 'NF >= 3 && $3 ~ /^[0-9]+$/ {print $3; exit}' "${MEMORY_LOG}")"
LAST_RSS="$(awk 'NF >= 3 && $3 ~ /^[0-9]+$/ {rss=$3} END {print rss}' "${MEMORY_LOG}")"
if [[ -n "${FIRST_RSS}" && -n "${LAST_RSS}" ]]; then
  echo "rss_start_kib=${FIRST_RSS}"
  echo "rss_end_kib=${LAST_RSS}"
  echo "rss_growth_kib=$((LAST_RSS - FIRST_RSS))"
fi

echo
echo "== Network counters before =="
cat "${COUNTER_BEFORE}"
echo
echo "== Network counters after =="
cat "${COUNTER_AFTER}"

echo
echo "Logs: ${INFO_LOG} ${MONITOR_LOG} ${MEMORY_LOG}"

if [[ "${MONITOR_STATUS}" -ne 0 ]]; then
  echo "FAIL: monitor reported status ${MONITOR_STATUS}; post-test evidence was still captured." >&2
  exit "${MONITOR_STATUS}"
fi

echo "PASS: bounded stability test completed without observed message continuity errors."
