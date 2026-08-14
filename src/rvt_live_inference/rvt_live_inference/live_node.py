#!/usr/bin/env python3
import sys
import time
from pathlib import Path

import numpy as np
import rclpy
from jetson_evt21_decoder.msg import DecodedEventPacket
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import Image
from std_msgs.msg import String



class RvtLiveNode(Node):
    def __init__(self):
        super().__init__('rvt_live_inference')
        self.declare_parameter('rvt_root', '/home/anavs/jetson-containers/data/RVT')
        self.declare_parameter('checkpoint', '/home/anavs/jetson-containers/data/RVT/checkpoints/rvt-t-gen4.ckpt')
        self.declare_parameter('device', 'cuda')
        self.declare_parameter('input_topic', '/metavision_driver/events_decoded')
        self.declare_parameter('detection_topic', '/rvt/detections')
        self.declare_parameter('visualization_topic', '/rvt/visualization')
        self.declare_parameter('overlay_topic', '/rvt/detection_overlay')
        self.declare_parameter('window_ms', 50.0)
        self.declare_parameter('confidence_threshold', 0.1)
        self.declare_parameter('nms_threshold', 0.45)

        self.rvt_root = Path(self.get_parameter('rvt_root').value)
        self.checkpoint = Path(self.get_parameter('checkpoint').value)
        self.device_name = str(self.get_parameter('device').value)
        self.window_ns = int(float(self.get_parameter('window_ms').value) * 1e6)
        self.confidence = float(self.get_parameter('confidence_threshold').value)
        self.nms = float(self.get_parameter('nms_threshold').value)
        self._load_rvt()

        input_topic = str(self.get_parameter('input_topic').value)
        self.det_pub = self.create_publisher(String, str(self.get_parameter('detection_topic').value), 10)
        self.viz_pub = self.create_publisher(Image, str(self.get_parameter('visualization_topic').value), 2)
        self.overlay_pub = self.create_publisher(Image, str(self.get_parameter("overlay_topic").value), 2)
        event_qos = QoSProfile(depth=10, reliability=ReliabilityPolicy.BEST_EFFORT, durability=DurabilityPolicy.VOLATILE)
        self.sub = self.create_subscription(DecodedEventPacket, input_topic, self.on_events, event_qos)
        self.x, self.y, self.t, self.p = [], [], [], []
        self.window_start = None
        self.last_seq = None
        self.total_events = 0
        self.event_canvas = np.zeros((720, 1280, 3), dtype=np.uint8)
        self.get_logger().info(f'RVT live wrapper ready; checkpoint={self.checkpoint}')

    def _load_rvt(self):
        if not self.rvt_root.is_dir():
            raise RuntimeError(f'RVT root does not exist: {self.rvt_root}')
        if not self.checkpoint.is_file():
            raise RuntimeError(f'RVT checkpoint does not exist: {self.checkpoint}')
        sys.path.insert(0, str(self.rvt_root))
        import torch
        from hydra import compose, initialize_config_dir
        from modules.detection import Module
        from models.detection.yolox.utils.boxes import postprocess
        from data.utils.representations import StackedHistogram
        self.torch = torch
        self.postprocess = postprocess
        self.representation = StackedHistogram(bins=10, height=720, width=1280)
        with initialize_config_dir(version_base='1.2', config_dir=str(self.rvt_root / 'config')):
            cfg = compose(config_name='val', overrides=['dataset=gen4', '+experiment/gen4=tiny.yaml'])
        from config.modifier import dynamically_modify_train_config
        dynamically_modify_train_config(cfg)
        self.model = Module(cfg)
        state = torch.load(str(self.checkpoint), map_location='cpu')
        state_dict = state.get('state_dict', state)
        self.model.load_state_dict(state_dict, strict=True)
        self.model.eval()
        self.model.to(self.device_name)
        self.device = torch.device(self.device_name)
        self.cfg = cfg
        self.previous_states = None

    def on_events(self, msg):
        if not msg.t:
            return
        self.total_events += len(msg.t)
        if self.last_seq is not None and msg.seq != self.last_seq + 1:
            self.get_logger().warning(f'input sequence gap: previous={self.last_seq}, current={msg.seq}')
        self.last_seq = msg.seq
        for i, (t, x, y, p) in enumerate(zip(msg.t, msg.x, msg.y, msg.polarity)):
            if i >= 5000:
                break
            if self.window_start is None:
                self.window_start = t
            self.x.append(x); self.y.append(y); self.t.append(t); self.p.append(1 if p > 0 else 0)
        if self.t and (self.t[-1] - self.window_start >= self.window_ns or len(self.t) >= 5000):
            self.run_window(msg.header, msg.seq)

    def run_window(self, header, source_seq):
        x = self.torch.tensor(self.x, dtype=self.torch.int64, device=self.device)
        y = self.torch.tensor(self.y, dtype=self.torch.int64, device=self.device)
        p = self.torch.tensor(self.p, dtype=self.torch.int64, device=self.device)
        t = self.torch.tensor(self.t, dtype=self.torch.int64, device=self.device)
        event_count = len(self.t)
        self.event_canvas = (self.event_canvas.astype(np.float32) * 0.75).astype(np.uint8)
        for xx, yy, pol in zip(self.x, self.y, self.p):
            if 0 <= xx < 1280 and 0 <= yy < 720:
                self.event_canvas[yy, xx] = [255, 40, 40] if pol else [40, 80, 255]
        self.x, self.y, self.t, self.p = [], [], [], []
        self.window_start = None
        with self.torch.inference_mode():
            t0 = time.perf_counter()
            ev = self.representation.construct(x=x, y=y, pol=p, time=t)
            ev = ev.unsqueeze(0).to(dtype=self.torch.float32)
            ev = self.torch.nn.functional.interpolate(ev, size=(360, 640), mode='nearest')
            ev = self.model.input_padder.pad_tensor_ev_repr(ev)
            raw, _, self.previous_states = self.model.forward(
                ev, previous_states=self.previous_states, retrieve_detections=True)
            pred = self.postprocess(raw, num_classes=self.cfg.model.head.num_classes,
                                    conf_thre=self.confidence, nms_thre=self.nms)
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
        detections = []
        if pred and pred[0] is not None:
            for row in pred[0].detach().cpu().numpy():
                detections.append({'class_id': int(row[6]), 'confidence': float(row[4]),
                                   'x': float(row[0]), 'y': float(row[1]),
                                   'width': float(row[2] - row[0]), 'height': float(row[3] - row[1])})
        import json
        out = String()
        out.data = json.dumps({'stamp_ns': int(header.stamp.sec * 1e9 + header.stamp.nanosec),
                               'source_seq': int(source_seq), 'input_event_count': event_count,
                               'inference_ms': elapsed_ms, 'detections': detections})
        self.det_pub.publish(out)
        # Publish a lightweight grayscale event visualization. The maximum over
        # the 20 histogram channels is sufficient for the first live milestone.
        image = Image()
        image.header = header
        image.height = 720; image.width = 1280
        image.encoding = 'rgb8'; image.is_bigendian = False; image.step = 1280 * 3
        image.data = self.event_canvas.tobytes()
        self.viz_pub.publish(image)
        self.publish_overlay(image, detections)
        self.get_logger().info(f'window events={event_count}, detections={len(detections)}, inference_ms={elapsed_ms:.2f}')


    def publish_overlay(self, image, detections):
        if image.encoding == 'mono8':
            gray = np.frombuffer(image.data, dtype=np.uint8).reshape((image.height, image.width))
            overlay = np.repeat(gray[:, :, None], 3, axis=2)
        else:
            overlay = np.frombuffer(image.data, dtype=np.uint8).reshape((image.height, image.width, 3)).copy()
        h, w = image.height, image.width
        for d in detections:
            x0 = max(0, min(w - 1, int(round(d["x"] * w / 640.0))))
            y0 = max(0, min(h - 1, int(round(d["y"] * h / 360.0))))
            x1 = max(0, min(w - 1, int(round((d["x"] + d["width"]) * w / 640.0))))
            y1 = max(0, min(h - 1, int(round((d["y"] + d["height"]) * h / 360.0))))
            overlay[max(0, y0 - 2):min(h, y1 + 3), max(0, x0 - 2):min(w, x0 + 3), :] = [255, 0, 0]
            overlay[max(0, y0 - 2):min(h, y1 + 3), max(0, x1 - 2):min(w, x1 + 3), :] = [255, 0, 0]
            overlay[max(0, y0 - 2):min(h, y0 + 3), max(0, x0 - 2):min(w, x1 + 3), :] = [255, 0, 0]
            overlay[max(0, y1 - 2):min(h, y1 + 3), max(0, x0 - 2):min(w, x1 + 3), :] = [255, 0, 0]
        out = Image()
        out.header = image.header
        out.height = h; out.width = w; out.encoding = "rgb8"; out.is_bigendian = False; out.step = w * 3
        out.data = overlay.tobytes()
        self.overlay_pub.publish(out)

def main(args=None):
    rclpy.init(args=args)
    node = RvtLiveNode()
    try:
        rclpy.spin(node)
    except rclpy.executors.ExternalShutdownException:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
