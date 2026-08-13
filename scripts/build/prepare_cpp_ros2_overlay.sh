#!/usr/bin/env bash
set -euo pipefail

mountpoint -q /data || { echo "ERROR: /data is not mounted" >&2; exit 1; }

source_prefix=/data/tools/ros2-humble-20231122/ros2-linux
overlay=/data/tools/ros2-humble-cpp-overlay

if [[ -e "${overlay}" ]]; then
  echo "ERROR: overlay already exists: ${overlay}" >&2
  echo "Remove it only after reviewing its exact contents." >&2
  exit 1
fi

mkdir -p "${overlay}"
cp -a "${source_prefix}/share" "${overlay}/share"
ln -s "${source_prefix}/lib" "${overlay}/lib"
ln -s "${source_prefix}/include" "${overlay}/include"
ln -s "${source_prefix}/bin" "${overlay}/bin"

# Keep the overlay C++/DDS-only.  This does not edit the original ROS prefix;
# it removes Python generator target tokens and absolute Python 3.10 linker
# paths only from the copied CMake export metadata.
find "${overlay}/share" -type f -path '*/cmake/*' -print0 |
  xargs -0 perl -pi -e 's{;[^;"\n]*rosidl_generator_py[^;"\n]*(?=;|")}{}g; s{(^|\n)[^\n]*export_[^\n]*rosidl_generator_py[^\n]*\n}{$1}g; s{/usr/lib/aarch64-linux-gnu/libpython3\.10\.so;?}{}g'

printf 'C++ ROS2 overlay: %s\n' "${overlay}"
