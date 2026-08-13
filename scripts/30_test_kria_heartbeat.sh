#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: $0 KRIA_WIRED_IP" >&2
  exit 2
fi

KRIA_IP="$1"
if ! [[ "${KRIA_IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "STOP: provide the confirmed numeric Kria wired IPv4 address." >&2
  exit 2
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/config/jetson_ros2_env.sh"

echo "== Environment =="
printenv | grep -E \
  '^(ROS_DISTRO|ROS_DOMAIN_ID|RMW_IMPLEMENTATION|ROS_LOCALHOST_ONLY)=' \
  | sort

echo
echo "== Route =="
ROUTE="$(ip route get "${KRIA_IP}")"
echo "${ROUTE}"
if [[ "${ROUTE}" != *" dev eth0 "* ]]; then
  echo "STOP: route to Kria does not use eth0." >&2
  exit 3
fi

echo
echo "== Wired reachability =="
ping -I eth0 -c 4 -W 2 "${KRIA_IP}"

echo
echo "== DDS discovery =="
ros2 daemon stop || true
FOUND=0
for _ in $(seq 1 20); do
  if ros2 topic list 2>/dev/null | grep -Fxq '/kria/heartbeat'; then
    FOUND=1
    break
  fi
  sleep 1
done
if [[ "${FOUND}" -ne 1 ]]; then
  echo "FAIL: /kria/heartbeat was not discovered within 20 seconds." >&2
  exit 4
fi

ros2 topic info --verbose /kria/heartbeat
TOPIC_TYPE="$(ros2 topic type /kria/heartbeat)"
if [[ -z "${TOPIC_TYPE}" ]]; then
  echo "FAIL: could not resolve the heartbeat topic type." >&2
  exit 5
fi
echo "Resolved type: ${TOPIC_TYPE}"

echo
echo "== Receive one message =="
timeout 20 ros2 topic echo /kria/heartbeat "${TOPIC_TYPE}" --once

echo
echo "== Sample rate for 15 seconds =="
HZ_OUTPUT="$(mktemp)"
trap 'rm -f "${HZ_OUTPUT}"' EXIT
set +e
timeout --signal=INT 15 ros2 topic hz /kria/heartbeat | tee "${HZ_OUTPUT}"
HZ_STATUS=${PIPESTATUS[0]}
set -e
if [[ "${HZ_STATUS}" -ne 0 && "${HZ_STATUS}" -ne 124 && "${HZ_STATUS}" -ne 130 ]]; then
  echo "FAIL: ros2 topic hz exited with status ${HZ_STATUS}." >&2
  exit "${HZ_STATUS}"
fi
if ! grep -q 'average rate:' "${HZ_OUTPUT}"; then
  echo "FAIL: ros2 topic hz did not measure a message rate." >&2
  exit 6
fi

echo
echo "Heartbeat discovery, receipt, and rate sampling completed."
