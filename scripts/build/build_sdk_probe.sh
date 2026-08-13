#!/bin/sh
set -eu

if ! mountpoint -q /data; then
  echo "ERROR: /data is not mounted; refusing to build." >&2
  exit 10
fi

workspace_root=${ROS2_WORKSPACE_ROOT:-/data/workspaces/ROS2}
build_root=${ROS2_BUILD_ROOT:-/data/builds/ROS2/kria_sdk_probe}
source_root="$workspace_root/src/kria_sdk_probe"

if [ ! -f "$source_root/CMakeLists.txt" ]; then
  echo "ERROR: probe source not found: $source_root" >&2
  exit 11
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "ERROR: cmake is not available." >&2
  exit 12
fi

if ! command -v c++ >/dev/null 2>&1 && ! command -v g++ >/dev/null 2>&1 &&
  ! command -v clang++ >/dev/null 2>&1; then
  echo "ERROR: no C++ compiler is available; refusing to configure." >&2
  echo "Required: c++, g++, or clang++ plus a matching target sysroot." >&2
  exit 13
fi

mkdir -p "$build_root"
cmake -S "$source_root" -B "$build_root" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  "$@"
cmake --build "$build_root" --parallel "${ROS2_BUILD_JOBS:-2}"
echo "Probe build completed: $build_root/kria_sdk_probe"
