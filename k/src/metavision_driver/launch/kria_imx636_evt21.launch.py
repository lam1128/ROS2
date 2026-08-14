#!/usr/bin/env python3

import launch
from launch.actions import DeclareLaunchArgument, SetEnvironmentVariable
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    camera_name = LaunchConfiguration("camera_name")
    config_file = LaunchConfiguration("config_file")

    return launch.LaunchDescription([
        DeclareLaunchArgument("camera_name", default_value="metavision_driver"),
        DeclareLaunchArgument(
            "config_file",
            default_value="/data/workspaces/ROS2/src/metavision_driver/config/kria_imx636_evt21.yaml",
        ),
        SetEnvironmentVariable("V4L2_HEAP", "reserved"),
        SetEnvironmentVariable("V4L2_SENSOR_PATH", "/dev/v4l-subdev3"),
        Node(
            package="metavision_driver",
            executable="driver_node",
            name=camera_name,
            output="screen",
            parameters=[config_file],
        ),
    ])
