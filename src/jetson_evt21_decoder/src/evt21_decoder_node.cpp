#include "jetson_evt21_decoder/msg/decoded_event_packet.hpp"

#include <event_camera_msgs/msg/event_packet.hpp>
#include <rclcpp/rclcpp.hpp>

#include <cstdint>
#include <cstring>
#include <functional>
#include <memory>
#include <stdexcept>
#include <string>

namespace jetson_evt21_decoder
{
class Evt21DecoderNode final : public rclcpp::Node
{
  using RawPacket = event_camera_msgs::msg::EventPacket;
  using DecodedPacket = jetson_evt21_decoder::msg::DecodedEventPacket;

public:
  Evt21DecoderNode()
  : Node("evt21_decoder_node")
  {
    const auto input_topic = declare_parameter<std::string>(
      "input_topic", "/metavision_driver/events");
    const auto output_topic = declare_parameter<std::string>(
      "output_topic", "/metavision_driver/events_decoded");
    const auto queue_size = declare_parameter<int>("queue_size", 4);
    if (queue_size < 1) {
      throw std::runtime_error("queue_size must be at least 1");
    }

    publisher_ = create_publisher<DecodedPacket>(
      output_topic,
      rclcpp::QoS(rclcpp::KeepLast(static_cast<size_t>(queue_size)))
        .best_effort().durability_volatile());
    subscription_ = create_subscription<RawPacket>(
      input_topic,
      rclcpp::QoS(rclcpp::KeepLast(static_cast<size_t>(queue_size)))
        .best_effort().durability_volatile(),
      std::bind(&Evt21DecoderNode::callback, this, std::placeholders::_1));

    RCLCPP_INFO(
      get_logger(), "decoding %s -> %s (EVT21 vector format)",
      input_topic.c_str(), output_topic.c_str());
  }

private:
  static uint64_t word(const uint8_t * data)
  {
    uint64_t value = 0;
    std::memcpy(&value, data, sizeof(value));
    return value;
  }

  void callback(const RawPacket::ConstSharedPtr packet)
  {
    if (packet->encoding.rfind("evt21", 0) != 0 || packet->events.size() % 8 != 0) {
      malformed_packets_++;
      return;
    }

    DecodedPacket decoded;
    decoded.header = packet->header;
    decoded.height = packet->height;
    decoded.width = packet->width;
    decoded.seq = packet->seq;
    decoded.t.reserve(packet->events.size() / 2);
    decoded.x.reserve(packet->events.size() / 2);
    decoded.y.reserve(packet->events.size() / 2);
    decoded.polarity.reserve(packet->events.size() / 2);

    for (size_t offset = 0; offset < packet->events.size(); offset += 8) {
      const uint64_t raw = word(packet->events.data() + offset);
      const uint8_t type = static_cast<uint8_t>(raw >> 60);
      if (type == 0x8) {  // TIME_HIGH
        last_high_timestamp_ = ((raw >> 32) & 0x0fffffffULL) << 6;
        continue;
      }
      if (type != 0x0 && type != 0x1) {
        continue;
      }

      const uint16_t base_x = static_cast<uint16_t>((raw >> 43) & 0x7ff);
      const uint16_t y = static_cast<uint16_t>((raw >> 32) & 0x7ff);
      const uint8_t event_ts = static_cast<uint8_t>((raw >> 26) & 0x3f);
      const uint32_t valid = static_cast<uint32_t>(raw & 0xffffffffULL);
      const uint64_t timestamp = (last_high_timestamp_ & ~0x3fULL) | event_ts;

      for (uint32_t mask = valid; mask != 0; mask &= mask - 1) {
        const uint16_t bit = static_cast<uint16_t>(__builtin_ctz(mask));
        decoded.x.push_back(static_cast<uint16_t>(base_x + bit));
        decoded.y.push_back(y);
        decoded.t.push_back(timestamp);
        decoded.polarity.push_back(type == 0x1 ? 1 : 0);
      }
    }

    decoded_packets_++;
    decoded_events_ += decoded.t.size();
    publisher_->publish(std::move(decoded));
  }

  rclcpp::Subscription<RawPacket>::SharedPtr subscription_;
  rclcpp::Publisher<DecodedPacket>::SharedPtr publisher_;
  uint64_t last_high_timestamp_{0};
  uint64_t decoded_packets_{0};
  uint64_t decoded_events_{0};
  uint64_t malformed_packets_{0};
};
}  // namespace jetson_evt21_decoder

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<jetson_evt21_decoder::Evt21DecoderNode>());
  rclcpp::shutdown();
  return 0;
}
