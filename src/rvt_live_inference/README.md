# RVT live inference ROS2 wrapper

This package connects the Jetson EVT21 decoder to the official RVT repository.
It does not copy or modify RVT. The model code and checkpoint remain in:

```text
/home/anavs/jetson-containers/data/RVT
```

The first milestone publishes detections as JSON in `std_msgs/String` and a
grayscale event image in `sensor_msgs/Image`:

```text
/metavision_driver/events_decoded -> /rvt/detections
                                  -> /rvt/visualization
```

The RVT Python dependencies are available in the `rvt:jetson` container. The
host ROS2 Humble libraries are mounted into that container when running the
node, because the host Python environment does not contain PyTorch.
