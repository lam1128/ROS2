# IMX636 to Jetson event stream test

Date: 2026-08-06

## Result

The bounded end-to-end transport test passed:

```text
IMX636
  -> KV260 V4L2 / Metavision HAL
  -> metavision_driver
  -> ROS 2 Fast DDS
  -> wired Ethernet
  -> Jetson EventPacket subscriber
```

This proves that raw camera packets can reach the Jetson through ROS 2 DDS.
It does not prove lossless, indefinitely sustainable transport at the
camera's unrestricted rate.

## Safety and ownership

- Active Marker was stopped.
- `metavision_viewer` opened the IMX636 successfully and was then closed.
- No viewer, Active Marker, or driver process owned the camera when the driver
  test began.
- The original driver source, installed driver library, system libraries,
  FPGA files, and Active Marker files were not replaced.

## Compatibility findings

The embedded HAL reports:

```text
evt21;height=720;width=1280
```

The upstream driver accepted only `evt3`, although the embedded plugin and
hardware provide EVT21. A temporary library was built under:

```text
/tmp/metavision_driver_evt21/libdriver_ros2.so
```

It permits EVT21 only as an accurately labelled raw `EventPacket` payload.
The installed driver remains unchanged. `event_camera_codecs` does not
currently decode EVT21, so this test measured transport rather than decoded
event coordinates.

## Camera and publisher evidence

```text
Plugin: hal_plugin_prophesee
Sensor: IMX636, version 4.2
Geometry: 1280 x 720
Encoding: evt21;height=720;width=1280
Topic: /metavision_driver/events
Type: event_camera_msgs/msg/EventPacket
QoS: BEST_EFFORT, VOLATILE
```

Before a subscriber connected, the Kria reported approximately 139 MiB/s and
138-139 input callback messages/s. Each observed raw callback block was
1 MiB.

## Jetson measurement

Fifteen-second subscriber result:

```text
packets: 808
packet rate: 53.810 Hz
payload: 847249408 bytes
payload rate: 53.810 MiB/s
first sequence: 3
last sequence: 810
observed sequence gaps: 0
geometry: 1280 x 720
encoding: evt21;height=720;width=1280
```

Log:

```text
/home/anavs/ROS2/logs/35_event_stream_2026-08-06_154755.log
```

## Throughput limitation

The camera-side input rate was approximately 139 MiB/s while Jetson received
53.81 MiB/s. A 1 Gb/s link cannot carry 139 MiB/s plus DDS, UDP, IP, and
Ethernet overhead.

The driver's multithreaded raw callback uses an unbounded internal queue.
When DDS publishing is slower than camera input, that queue can grow. During
the test, the Kria log showed roughly 139 input blocks/s and about 61 output
messages/s as the subscriber connected. The process RSS after the bounded
test was approximately 643 MiB.

The continuous ROS sequence numbers prove that the packets which the driver
published were received without an observed DDS sequence gap. They do not
account for data waiting in or lost before the publish path.

## Decision

- Camera discovery and acquisition: `PASS`
- EventPacket publication: `PASS`
- Cross-host Fast DDS reception: `PASS`
- Nonzero packet and payload rates: `PASS`
- DDS sequence continuity during the bounded sample: `PASS`
- EVT21 decoding on Jetson: `NOT SUPPORTED`
- Sustained full-rate, lossless operation: `NOT PROVEN`

Before a longer run, add an explicit rate-control or backpressure strategy and
bound the driver queue with observable drop counters. Do not leave this test
driver running unattended, and never restart Active Marker until the driver
has exited and released the camera.

## Five-minute follow-up

The later maintained Kria build used:

```text
/data/builds/ROS2/metavision_driver_20260806_070856/install/metavision_driver
```

Its IMX636 configuration sets `use_multithreading: false`, avoiding the
earlier unbounded user-space queue. Three 300-second attempts were recorded:

| Attempt | Packets | Rate | Payload | Sequence gaps | Timestamp regressions | Kria RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 16:26 | 16,326 | 54.419 Hz | 54.419 MiB/s | 8 | 0 | stable near 77,424 KiB |
| 16:40 | 0 | 0 | 0 | 0 | 0 | stable near 46,968 KiB |
| 16:57 | 16,276 | 54.252 Hz | 54.252 MiB/s | 4 | 0 | stable near 77,308 KiB |

The two valid streaming runs show stable process memory and monotonic header
timestamps, but they also show a small number of missing published sequence
numbers under BEST_EFFORT QoS. The zero-packet run discovered the publisher
but did not receive data and is not a successful stability run.

The original stability script returned immediately after a continuity error,
so those attempts lack an end-of-test network counter snapshot. The script
has since been corrected to capture memory and final network counters before
returning the monitor failure status.

Updated decision:

- Five-minute memory stability: `PASS` in two valid streaming runs.
- Timestamp monotonicity: `PASS` in two valid streaming runs.
- Five-minute zero-gap DDS transport: `FAIL` (8 gaps, then 4 gaps).
- Five-minute repeatability: `FAIL` because one attempt delivered zero data.
- Production-ready lossless transport: `NOT PROVEN`.
