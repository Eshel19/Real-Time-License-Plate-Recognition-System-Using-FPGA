#ifndef FPGA_PIO_API_HPP
#define FPGA_PIO_API_HPP

#include <cstdint>
#include <vector>
#include <string>

namespace fpga {

    struct PioStatus {
        uint32_t raw = 0;
        bool pio_out_ready = false;   // bit 0
        bool pio_in_valid = false;   // bit 1
        bool busy = false;   // bit 2
        bool result_ready = false; //bit 3
        bool error_flag = false;   // bit 4
        uint8_t fsm_state = 0;       // bits 9:6
        uint8_t images_processed = 0;     // bits 15:8
        uint8_t images_with_digits = 0;   // bits 23:16
    };

    class FpgaPioApi {
    public:
        explicit FpgaPioApi(uint32_t timeout_cycles = 1000, bool debug = false, bool unsafe_mode_=false);
        ~FpgaPioApi();

        bool initialize();
        void cleanup();

        bool write128(const std::vector<uint8_t>& word);
        bool read128(std::vector<uint8_t>& word_out);

        bool writeBurst128(const std::vector<std::vector<uint8_t>>& burst_data, size_t expected_words);
        bool readBurst128(std::vector<std::vector<uint8_t>>& burst_out, size_t expected_words);

        void writeCmd(uint32_t cmd);
        PioStatus readStatus() const;

    private:
        bool waitForOutReady();
        bool waitForInValid();
        bool unsafe_mode_ = false;
        bool is_initialized_ = false;
        bool debug_ = false;
        int fd_ = -1;
        uint32_t timeout_cycles_;

        static constexpr size_t word_size = 16;

        volatile uint8_t* bridge_map_ = nullptr;
        volatile uint8_t* lw_bridge_map_ = nullptr;
    };

} // namespace fpga

#endif // FPGA_PIO_API_HPP
