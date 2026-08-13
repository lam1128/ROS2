cmake_minimum_required(VERSION 3.8)
project(jetson_evt21_decoder)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)
find_package(event_camera_msgs REQUIRED)
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/DecodedEventPacket.msg"
  DEPENDENCIES std_msgs
)

add_executable(evt21_decoder_node src/evt21_decoder_node.cpp)
ament_target_dependencies(evt21_decoder_node rclcpp std_msgs event_camera_msgs)
target_compile_options(evt21_decoder_node PRIVATE -Wall -Wextra -Wpedantic)
rosidl_get_typesupport_target(cpp_typesupport_target ${PROJECT_NAME} "rosidl_typesupport_cpp")
target_link_libraries(evt21_decoder_node "${cpp_typesupport_target}")
add_dependencies(evt21_decoder_node ${PROJECT_NAME}__rosidl_generator_cpp)

install(TARGETS evt21_decoder_node DESTINATION lib/${PROJECT_NAME})
install(FILES README.md DESTINATION share/${PROJECT_NAME})

ament_export_dependencies(rosidl_default_runtime)
ament_package()
