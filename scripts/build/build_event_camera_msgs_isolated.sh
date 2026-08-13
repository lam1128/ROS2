#!/usr/bin/env bash
set -euo pipefail

mountpoint -q /data || { echo "ERROR: /data is not mounted" >&2; exit 1; }

workspace=/data/workspaces/ROS2
ros_prefix=/data/tools/ros2-humble-20231122/ros2-linux
sysroot=/data/tools/kria-build-root
colcon_prefix=/data/tools/colcon-python3.9
python_prefix=/data/tools/ros2-python3.9
stamp="$(date +%Y%m%d_%H%M%S)"
output="/data/builds/ROS2/event_camera_msgs_${stamp}"

export PATH="${colcon_prefix}/bin:${ros_prefix}/bin:${sysroot}/usr/bin:${PATH}"
export PYTHONPATH="${python_prefix}:${ros_prefix}/lib/python3.10/site-packages:${colcon_prefix}:${PYTHONPATH:-}"
export AMENT_PREFIX_PATH="${ros_prefix}"
export CMAKE_PREFIX_PATH="${ros_prefix}:${sysroot}/usr:${sysroot}/usr/lib/aarch64-linux-gnu"
export LD_LIBRARY_PATH="${ros_prefix}/lib:${sysroot}/usr/lib:${sysroot}/usr/lib/aarch64-linux-gnu:${sysroot}/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="${ros_prefix}/lib/pkgconfig:${sysroot}/usr/lib/pkgconfig:${sysroot}/usr/lib/aarch64-linux-gnu/pkgconfig"
export ROS_VERSION=2
export ROS_DISTRO=humble

mkdir -p "${output}/build" "${output}/install" "${output}/log"

# The extracted binary archive has package-index entries but incomplete CMake
# prefix discovery when used with the target toolchain. Pass every available
# ROS package CMake directory explicitly; this does not alter the system.
cmake_args=(
  -DCMAKE_TOOLCHAIN_FILE="${workspace}/config/kria-build-toolchain.cmake"
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_TESTING=OFF
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=NEVER
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH
  -DPYTHON_INCLUDE_DIR=/usr/include/python3.9
  -DPYTHON_LIBRARY=/usr/lib/libpython3.9.so.1.0
  "-DCMAKE_C_FLAGS=-I${ros_prefix}/include"
  "-DCMAKE_CXX_FLAGS=-I${ros_prefix}/include -I${ros_prefix}/include/fastcdr"
  -Dfastcdr_DIR="${workspace}/config/ros2_overrides"
  -Dfoonathan_memory_DIR="${workspace}/config/ros2_overrides"
  -Dyaml_DIR="${workspace}/config/ros2_overrides"
)
while IFS= read -r cmake_dir; do
  package_dir="$(dirname "${cmake_dir}")"
  package_name="$(basename "${package_dir}")"
  cmake_args+=("-D${package_name}_DIR=${cmake_dir}")
done < <(find "${ros_prefix}/share" -mindepth 3 -maxdepth 4 -type f -name '*Config.cmake' -printf '%h\n' | sort -u)

colcon --log-base "${output}/log" build \
  --base-paths "${workspace}/src/event_camera_msgs" \
  --build-base "${output}/build" \
  --install-base "${output}/install" \
  --cmake-args "${cmake_args[@]}"

printf 'event_camera_msgs install: %s\n' "${output}/install"
