// ocr_bridge_api.hpp
#pragma once

#include "fpga_pio_api.hpp"
#include <vector>
#include <string>
#include <cstdint>
#include <optional>

namespace ocr {

    enum class CommandType : uint8_t {
        INIT = 0x0,
        UPLOAD = 0x1,
        ACK_IRQ = 0x2,
        RESET = 0x3
    };

    enum class OcrFsmState : uint8_t {
        IDLE, WAIT_CMD, RECEIVE_IMG, INFER, SEND_RESULT, ERROR, UNKNOWN
    };

    struct OcrStatus {
        bool pio_out_ready;
        bool pio_in_valid;
        bool error_flag;
        OcrFsmState fsm_state;
        uint8_t images_processed;
        uint8_t images_with_digits;
    };

    class OcrBridge {
    public:
        OcrBridge(uint32_t timeout = 10000, bool debug = false);
        bool initialize();
        void reset();
        void ack_irq();
        bool upload_strip_info(uint8_t image_count, uint32_t strip_length);
        bool configure(uint8_t min_digits, uint8_t max_digits);

        OcrStatus read_status();
        bool is_busy();

        // Write helpers
        bool send_u16_array(const std::vector<uint16_t>& values);
        bool send_image(const std::vector<std::vector<int8_t>>& image); // [16][width]

        // Read helper
        std::optional<std::vector<std::string>> receive_results();

    private:
        fpga::FpgaPioApi fpga_;
    };

} // namespace ocr
