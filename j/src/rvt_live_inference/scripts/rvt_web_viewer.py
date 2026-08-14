#!/usr/bin/env python3
import io
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import Image

HTML = """<!doctype html><html><head><meta charset='utf-8'><title>RVT Live Viewer</title>
<style>body{background:#202124;color:#eee;font-family:sans-serif}main{display:flex;gap:16px;flex-wrap:wrap}section{background:#303134;padding:10px}img{max-width:calc(50vw - 40px);height:auto}h2{font-size:16px}</style>
</head><body><h1>RVT Live Inference</h1><main>
<section><h2>Event stream</h2><img src='/stream/events'></section>
<section><h2>Detection overlay</h2><img src='/stream/detections'></section>
</main></body></html>"""


class ViewerNode(Node):
    def __init__(self):
        super().__init__('rvt_web_viewer')
        self.lock = threading.Lock()
        self.frames = {'events': None, 'detections': None}
        qos = QoSProfile(depth=2, reliability=ReliabilityPolicy.RELIABLE,
                         durability=DurabilityPolicy.VOLATILE)
        self.create_subscription(Image, '/rvt/visualization',
                                 lambda msg: self.update('events', msg), qos)
        self.create_subscription(Image, '/rvt/detection_overlay',
                                 lambda msg: self.update('detections', msg), qos)

    def update(self, name, msg):
        try:
            from PIL import Image as PilImage
            if msg.encoding == 'mono8':
                image = PilImage.frombytes('L', (msg.width, msg.height), bytes(msg.data))
            elif msg.encoding == 'rgb8':
                image = PilImage.frombytes('RGB', (msg.width, msg.height), bytes(msg.data))
            else:
                return
            out = io.BytesIO()
            image.save(out, format='JPEG', quality=75)
            with self.lock:
                self.frames[name] = out.getvalue()
        except Exception as exc:
            self.get_logger().warning(f'frame conversion failed: {exc}')


NODE = None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path == '/':
            body = HTML.encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        name = {'/stream/events': 'events', '/stream/detections': 'detections'}.get(self.path)
        if name is None:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
        self.end_headers()
        while rclpy.ok():
            with NODE.lock:
                frame = NODE.frames.get(name)
            if frame:
                try:
                    header = b'--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ' + str(len(frame)).encode() + b'\r\n\r\n'
                    self.wfile.write(header + frame + b'\r\n')
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError):
                    break
            threading.Event().wait(0.05)


def main():
    global NODE
    rclpy.init()
    NODE = ViewerNode()
    server = ThreadingHTTPServer(('0.0.0.0', 8080), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    NODE.get_logger().info('web viewer ready on port 8080')
    try:
        rclpy.spin(NODE)
    finally:
        server.shutdown()
        NODE.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
