#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${ROOT_DIR}/logs"

section() {
  printf '\n== %s ==\n' "$1"
}

section "OS"
cat /etc/os-release
uname -a
printf 'dpkg architecture: %s\n' "$(dpkg --print-architecture)"

section "Jetson"
if [[ -r /etc/nv_tegra_release ]]; then
  cat /etc/nv_tegra_release
fi
if [[ -r /proc/device-tree/model ]]; then
  tr -d '\0' < /proc/device-tree/model
  printf '\n'
fi

section "ROS commands"
command -v ros2 || printf 'ros2: not installed\n'
command -v colcon || printf 'colcon: not installed\n'

section "ROS packages"
dpkg-query -W -f='${binary:Package}\t${Version}\n' \
  'ros-humble-*' 2>/dev/null || printf 'No ros-humble packages found.\n'

section "APT sources"
find /etc/apt/sources.list /etc/apt/sources.list.d \
  -maxdepth 1 \( -type f -o -type l \) -print 2>/dev/null

section "Network addresses"
ip -brief address

section "Routes"
ip route

section "Ethernet multicast membership"
ip maddr show dev eth0 2>&1 || true

section "Firewall tools (unprivileged view)"
if command -v ufw >/dev/null; then
  ufw status verbose 2>&1 || true
else
  printf 'ufw command is not installed.\n'
fi
if command -v nft >/dev/null; then
  nft list ruleset 2>&1 || true
else
  printf 'nft command is not installed.\n'
fi

section "Disk"
df -h / "${ROOT_DIR}"

section "Clock"
timedatectl status 2>&1 || true

section "ROS environment"
printenv | grep -E \
  '^(ROS_DISTRO|ROS_DOMAIN_ID|RMW_IMPLEMENTATION|ROS_LOCALHOST_ONLY)=' \
  || printf 'No selected ROS environment variables are set.\n'
