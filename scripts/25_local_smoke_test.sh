#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/config/jetson_ros2_env.sh"

STAMP="$(date +%F_%H%M%S)"
PUB_LOG="${ROOT_DIR}/logs/25_local_pub_${STAMP}.log"
ECHO_LOG="${ROOT_DIR}/logs/25_local_echo_${STAMP}.log"
HZ_LOG="${ROOT_DIR}/logs/25_local_hz_${STAMP}.log"
PUB_PID=""

cleanup() {
  if [[ -n "${PUB_PID}" ]]; then
    kill "${PUB_PID}" 2>/dev/null || true
    wait "${PUB_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

ros2 daemon stop >/dev/null 2>&1 || true

ros2 topic pub -r 10 /jetson/ros2_smoke std_msgs/msg/String \
  '{data: jetson_ros2_smoke}' >"${PUB_LOG}" 2>&1 &
PUB_PID=$!

FOUND=0
for _ in $(seq 1 20); do
  if ros2 topic list 2>/dev/null | grep -Fxq '/jetson/ros2_smoke'; then
    FOUND=1
    break
  fi
  sleep 0.5
done
if [[ "${FOUND}" -ne 1 ]]; then
  echo "FAIL: local smoke topic was not discovered." >&2
  exit 2
fi

timeout 10 ros2 topic echo /jetson/ros2_smoke std_msgs/msg/String --once \
  | tee "${ECHO_LOG}"
grep -q 'jetson_ros2_smoke' "${ECHO_LOG}"

set +e
timeout --signal=INT 8 ros2 topic hz /jetson/ros2_smoke | tee "${HZ_LOG}"
HZ_STATUS=${PIPESTATUS[0]}
set -e
if [[ "${HZ_STATUS}" -ne 0 && "${HZ_STATUS}" -ne 124 && "${HZ_STATUS}" -ne 130 ]]; then
  echo "FAIL: ros2 topic hz exited with status ${HZ_STATUS}." >&2
  exit "${HZ_STATUS}"
fi
if ! grep -q 'average rate:' "${HZ_LOG}"; then
  echo "FAIL: no local message rate was measured." >&2
  exit 3
fi

echo "PASS: local Fast DDS publish, discovery, echo, and rate test completed."
echo "Logs: ${PUB_LOG} ${ECHO_LOG} ${HZ_LOG}"

