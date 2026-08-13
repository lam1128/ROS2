#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(
  ros-humble-ros-base
  ros-humble-rmw-fastrtps-cpp
  python3-colcon-common-extensions
  build-essential
  cmake
)

if [[ "${1:-}" != "--apply" ]]; then
  cat <<'EOF'
DRY RUN ONLY: no system changes were made.

After review, run:
  ./scripts/10_install_humble.sh --apply

Planned actions:
  1. Require Ubuntu 22.04 (jammy) and ARM64.
  2. Install curl and software-properties-common if needed.
  3. Install the official ros2-apt-source repository package for jammy.
  4. Run apt-get update.
  5. Install ROS base, Fast DDS RMW, colcon, build-essential, and cmake.

No apt upgrade, shell startup edit, firewall/network edit, camera package,
event message, OpenEB, RVT, FPGA, overlay, Active Marker, or Kria change.
EOF
  printf '\nPackages:\n'
  printf '  %s\n' "${PACKAGES[@]}"
  exit 0
fi

source /etc/os-release
ARCH="$(dpkg --print-architecture)"
if [[ "${ID:-}" != "ubuntu" || "${VERSION_CODENAME:-}" != "jammy" ]]; then
  echo "STOP: requires Ubuntu 22.04 jammy; found ${PRETTY_NAME:-unknown}." >&2
  exit 2
fi
if [[ "${ARCH}" != "arm64" ]]; then
  echo "STOP: requires arm64; found ${ARCH}." >&2
  exit 2
fi

echo "Target verified: ${PRETTY_NAME}, ${ARCH}"
echo "This will modify Jetson APT state and install the listed packages."
sudo apt-get update
sudo apt-get install -y curl software-properties-common

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
ROS_APT_VERSION="$(
  curl -fsSL https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
    | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1
)"
if [[ -z "${ROS_APT_VERSION}" ]]; then
  echo "STOP: could not determine the current ros-apt-source release." >&2
  exit 3
fi

ROS_APT_DEB="ros2-apt-source_${ROS_APT_VERSION}.jammy_all.deb"
curl -fL \
  "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_VERSION}/${ROS_APT_DEB}" \
  -o "${TMP_DIR}/${ROS_APT_DEB}"
sudo dpkg -i "${TMP_DIR}/${ROS_APT_DEB}"
sudo apt-get update

echo
echo "Review the following APT simulation. Stop if it removes NVIDIA packages."
sudo apt-get install --simulate "${PACKAGES[@]}"
read -r -p "Type INSTALL to continue: " CONFIRM
if [[ "${CONFIRM}" != "INSTALL" ]]; then
  echo "Installation cancelled."
  exit 4
fi

sudo apt-get install "${PACKAGES[@]}"
echo "Installation finished. No ROS environment was added to shell startup."
