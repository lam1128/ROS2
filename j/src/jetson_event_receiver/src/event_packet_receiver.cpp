#include <event_camera_msgs/msg/event_packet.hpp>
#include <rclcpp/rclcpp.hpp>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <functional>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>

namespace jetson_event_receiver
{
class EventPacketReceiver final : public rclcpp::Node
{
  using EventPacket = event_camera_msgs::msg::EventPacket;

public:
  EventPacketReceiver()
  : Node("event_packet_receiver"),
    last_report_(std::chrono::steady_clock::now())
  {
    const auto topic = declare_parameter<std::string>(
      "topic", "/metavision_driver/events");
    const auto queue_size = declare_parameter<int>("queue_size", 4);
    const auto report_period = declare_parameter<double>("report_period_sec", 2.0);

    if (queue_size < 1 || report_period <= 0.0) {
      throw std::runtime_error("queue_size must be >= 1 and report_period_sec must be > 0");
    }

    subscription_ = create_subscription<EventPacket>(
      topic,
      rclcpp::QoS(rclcpp::KeepLast(static_cast<size_t>(queue_size)))
        .best_effort()
        .durability_volatile(),
      std::bind(&EventPacketReceiver::packet_callback, this, std::placeholders::_1));

    timer_ = create_wall_timer(
      std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::duration<double>(report_period)),
      std::bind(&EventPacketReceiver::report, this));

    RCLCPP_INFO(get_logger(), "subscribing to %s with queue depth %d", topic.c_str(), queue_size);
  }

private:
  void packet_callback(const EventPacket::ConstSharedPtr message)
  {
    const auto now = std::chrono::steady_clock::now();
    if (have_sequence_ && message->seq > last_sequence_ + 1) {
      sequence_gaps_ += message->seq - last_sequence_ - 1;
    }
    if (have_timestamp_ && message->header.stamp.sec < last_stamp_sec_) {
      timestamp_regressions_++;
    } else if (have_timestamp_ && message->header.stamp.sec == last_stamp_sec_ &&
               message->header.stamp.nanosec < last_stamp_nanosec_) {
      timestamp_regressions_++;
    }

    have_sequence_ = true;
    last_sequence_ = message->seq;
    have_timestamp_ = true;
    last_stamp_sec_ = message->header.stamp.sec;
    last_stamp_nanosec_ = message->header.stamp.nanosec;
    packets_++;
    bytes_ += message->events.size();
    last_packet_time_ = now;
    if (message->encoding.rfind("evt21", 0) != 0) {
      unexpected_encoding_++;
    }
  }

  void report()
  {
    const auto now = std::chrono::steady_clock::now();
    const double seconds = std::chrono::duration<double>(now - last_report_).count();
    if (seconds <= 0.0) {
      return;
    }

    const double mib_per_second =
      static_cast<double>(bytes_ - last_bytes_) / seconds / (1024.0 * 1024.0);
    const double packets_per_second =
      static_cast<double>(packets_ - last_packets_) / seconds;
    const double silence_seconds = last_packet_time_.time_since_epoch().count() == 0
      ? std::numeric_limits<double>::infinity()
      : std::chrono::duration<double>(now - last_packet_time_).count();

    RCLCPP_INFO(
      get_logger(),
      "packets/s=%.2f payload=%.2f MiB/s total_packets=%llu gaps=%llu "
      "timestamp_regressions=%llu unexpected_encoding=%llu silence=%.2fs",
      packets_per_second, mib_per_second,
      static_cast<unsigned long long>(packets_),
      static_cast<unsigned long long>(sequence_gaps_),
      static_cast<unsigned long long>(timestamp_regressions_),
      static_cast<unsigned long long>(unexpected_encoding_), silence_seconds);

    last_report_ = now;
    last_packets_ = packets_;
    last_bytes_ = bytes_;
  }

  rclcpp::Subscription<EventPacket>::SharedPtr subscription_;
  rclcpp::TimerBase::SharedPtr timer_;
  std::chrono::steady_clock::time_point last_report_;
  std::chrono::steady_clock::time_point last_packet_time_{};
  uint64_t packets_{0};
  uint64_t bytes_{0};
  uint64_t last_packets_{0};
  uint64_t last_bytes_{0};
  uint64_t last_sequence_{0};
  uint64_t sequence_gaps_{0};
  uint64_t timestamp_regressions_{0};
  uint64_t unexpected_encoding_{0};
  int32_t last_stamp_sec_{0};
  uint32_t last_stamp_nanosec_{0};
  bool have_sequence_{false};
  bool have_timestamp_{false};
};
}  // namespace jetson_event_receiver

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<jetson_event_receiver::EventPacketReceiver>());
  rclcpp::shutdown();
  return 0;
}
