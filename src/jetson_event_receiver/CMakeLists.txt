cmake_minimum_required(VERSION 3.8)
project(jetson_event_receiver)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(event_camera_msgs REQUIRED)

add_executable(event_packet_receiver src/event_packet_receiver.cpp)
ament_target_dependencies(event_packet_receiver rclcpp event_camera_msgs)
target_compile_options(event_packet_receiver PRIVATE -Wall -Wextra -Wpedantic)

install(TARGETS event_packet_receiver DESTINATION lib/${PROJECT_NAME})
install(FILES README.md DESTINATION share/${PROJECT_NAME})

ament_package()
