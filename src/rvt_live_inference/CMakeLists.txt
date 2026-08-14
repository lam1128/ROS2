cmake_minimum_required(VERSION 3.8)
project(rvt_live_inference)

find_package(ament_cmake REQUIRED)
find_package(ament_cmake_python REQUIRED)
find_package(rclpy REQUIRED)
find_package(std_msgs REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(jetson_evt21_decoder REQUIRED)
ament_python_install_package(${PROJECT_NAME})
install(PROGRAMS
  scripts/rvt_live_node
  scripts/rvt_web_viewer.py
  DESTINATION lib/${PROJECT_NAME}
)
install(DIRECTORY config DESTINATION share/${PROJECT_NAME})

ament_package()
