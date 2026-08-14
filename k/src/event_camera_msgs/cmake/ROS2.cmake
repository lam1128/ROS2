#
# Copyright 2021 Bernd Pfrommer <bernd.pfrommer@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(builtin_interfaces REQUIRED)
find_package(rosidl_default_generators REQUIRED)
find_package(std_msgs REQUIRED)

# The Kria image has Python 3.9 but the staged Ubuntu ROS archive contains
# Python 3.10 runtime artifacts.  The Kria C++ publisher/driver only needs C,
# C++ and DDS typesupport.  Keep Python generation opt-in for this isolated
# target build until a matching Python runtime is staged.
option(KRIA_SKIP_PYTHON_GENERATOR "Skip Python message extension generation" ON)
if(KRIA_SKIP_PYTHON_GENERATOR AND DEFINED AMENT_EXTENSIONS_rosidl_generate_idl_interfaces)
  list(FILTER AMENT_EXTENSIONS_rosidl_generate_idl_interfaces
    EXCLUDE REGEX "^rosidl_generator_py:")
endif()

rosidl_generate_interfaces(${PROJECT_NAME}
  msg_ros2/EventPacket.msg
  DEPENDENCIES builtin_interfaces std_msgs)


if(BUILD_TESTING)
  find_package(ament_cmake REQUIRED)
  find_package(ament_cmake_copyright REQUIRED)
  find_package(ament_cmake_lint_cmake REQUIRED)
  find_package(ament_cmake_xmllint REQUIRED)

  ament_copyright()
  ament_lint_cmake()
  ament_xmllint()
endif()


ament_export_dependencies(rosidl_default_runtime)

ament_package()
