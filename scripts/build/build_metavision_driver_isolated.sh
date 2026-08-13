#!/usr/bin/env bash
set -euo pipefail

mountpoint -q /data || { echo "ERROR: /data is not mounted" >&2; exit 1; }

workspace=/data/workspaces/ROS2
ros_prefix=/data/tools/ros2-humble-20231122/ros2-linux
cpp_prefix=/data/tools/ros2-humble-cpp-overlay
sysroot=/data/tools/kria-build-root
colcon_prefix=/data/tools/colcon-python3.9
event_prefix="$(find /data/builds/ROS2 -maxdepth 1 -type d -name 'event_camera_msgs_20260806_*' | sort | tail -1)/install/event_camera_msgs"
openeb_prefix=/data/builds/ROS2/openeb-5.0.0-minimal
console_prefix=/data/builds/ROS2/console_bridge_20260806/install2
stamp="$(date +%Y%m%d_%H%M%S)"
output="/data/builds/ROS2/metavision_driver_${stamp}"

test -f "${event_prefix}/share/event_camera_msgs/cmake/event_camera_msgsConfig.cmake" || {
  echo "ERROR: build event_camera_msgs first" >&2; exit 1;
}

export PATH="${colcon_prefix}/bin:${ros_prefix}/bin:${sysroot}/usr/bin:${PATH}"
export PYTHONPATH="/data/tools/ros2-python3.9:${ros_prefix}/lib/python3.10/site-packages:${colcon_prefix}:${PYTHONPATH:-}"
export AMENT_PREFIX_PATH="${event_prefix}:${console_prefix}:${cpp_prefix}:${ros_prefix}"
export CMAKE_PREFIX_PATH="${event_prefix}:${console_prefix}:${cpp_prefix}:${ros_prefix}:${sysroot}/usr"
export LD_LIBRARY_PATH="${event_prefix}/lib:${console_prefix}/lib:${ros_prefix}/lib:${openeb_prefix}/lib:${sysroot}/usr/lib:${sysroot}/usr/lib/aarch64-linux-gnu:${sysroot}/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="${ros_prefix}/lib/pkgconfig:${sysroot}/usr/lib/pkgconfig:${sysroot}/usr/lib/aarch64-linux-gnu/pkgconfig"
export ROS_VERSION=2
export ROS_DISTRO=humble

mkdir -p "${output}/build" "${output}/install" "${output}/log"

cmake_args=(
  -DCMAKE_TOOLCHAIN_FILE="${workspace}/config/kria-build-toolchain.cmake"
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_TESTING=OFF
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=NEVER
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=NEVER
  -DMetavisionSDK_DIR="${openeb_prefix}/generated/share/cmake/MetavisionSDKCMakePackagesFilesDir"
  -DMetavisionHAL_DIR="${openeb_prefix}/generated/share/cmake/MetavisionHALCMakePackagesFilesDir"
  -DMetavisionPSEEHWLayer_DIR="${openeb_prefix}/generated/share/cmake/MetavisionPSEEHWLayerCMakePackagesFilesDir"
  -Dament_cmake_DIR="${cpp_prefix}/share/ament_cmake/cmake"
  -Dament_cmake_auto_DIR="${cpp_prefix}/share/ament_cmake_auto/cmake"
  -Dament_cmake_ros_DIR="${cpp_prefix}/share/ament_cmake_ros/cmake"
  -Devent_camera_msgs_DIR="${event_prefix}/share/event_camera_msgs/cmake"
  -Dconsole_bridge_DIR="${console_prefix}/lib/console_bridge/cmake"
  -Dfastcdr_DIR="${workspace}/config/ros2_overrides"
  -Dfoonathan_memory_DIR="${workspace}/config/ros2_overrides"
  -Dyaml_DIR="${workspace}/config/ros2_overrides"
  -Dfastrtps_DIR="${ros_prefix}/share/fastrtps/cmake"
  -DFastRTPS_INCLUDE_DIR="${ros_prefix}/include"
  "-DFastRTPS_LIBRARIES=${ros_prefix}/lib/libfastrtps.so;${ros_prefix}/lib/libfastcdr.so"
  -DFastRTPS_LIBRARY_RELEASE="${ros_prefix}/lib/libfastrtps.so"
  -DFastCDR_LIBRARY_RELEASE="${ros_prefix}/lib/libfastcdr.so"
  -DPYTHON_INCLUDE_DIR=/usr/include/python3.9
  -DPYTHON_LIBRARY=/usr/lib/libpython3.9.so.1.0
  "-DCMAKE_CXX_FLAGS=-I${ros_prefix}/include -I${ros_prefix}/include/fastcdr"
)
while IFS= read -r cmake_dir; do
  package_dir="$(dirname "${cmake_dir}")"
  package_name="$(basename "${package_dir}")"
  cmake_args+=("-D${package_name}_DIR=${cmake_dir}")
done < <(find "${cpp_prefix}/share" -mindepth 3 -maxdepth 4 -type f -name '*Config.cmake' -printf '%h\n' | sort -u)

colcon --log-base "${output}/log" build \
  --base-paths "${workspace}/src/metavision_driver" \
  --build-base "${output}/build" \
  --install-base "${output}/install" \
  --cmake-args "${cmake_args[@]}"

printf 'metavision_driver install: %s\n' "${output}/install"
