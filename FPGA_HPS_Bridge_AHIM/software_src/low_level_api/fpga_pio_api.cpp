#include "fpga_pio_api.hpp"
#include "fpga_pio_address.hpp"

#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <cstring>
#include <cstdio>

using namespace fpga;

FpgaPioApi::FpgaPioApi(uint32_t timeout_cycles, bool debug,bool unsafe_mode_)
    : timeout_cycles_(timeout_cycles), debug_(debug), unsafe_mode_(unsafe_mode_){
}

FpgaPioApi::~FpgaPioApi() {
    cleanup();
}

bool FpgaPioApi::initialize() {
    fd_ = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd_ < 0) {
        perror("open /dev/mem");
        return false;
    }

    bridge_map_ = static_cast<volatile uint8_t*>(
        mmap(nullptr, BRIDGE_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, BRIDGE_BASE));
    if (bridge_map_ == MAP_FAILED) {
        perror("mmap bridge");
        close(fd_);
        fd_ = -1;
        return false;
    }

    lw_bridge_map_ = static_cast<volatile uint8_t*>(
        mmap(nullptr, LW_BRIDGE_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, LW_BRIDGE_BASE));
    if (lw_bridge_map_ == MAP_FAILED) {
        perror("mmap lw bridge");
        munmap((void*)bridge_map_, BRIDGE_SPAN);
        bridge_map_ = nullptr;
        close(fd_);
        fd_ = -1;
        return false;
    }

    is_initialized_ = true;
    if (debug_) printf("[Init] FPGA PIO API initialized\n");
    return true;
}

void FpgaPioApi::cleanup() {
    if (bridge_map_) {
        munmap((void*)bridge_map_, BRIDGE_SPAN);
        bridge_map_ = nullptr;
    }
    if (lw_bridge_map_) {
        munmap((void*)lw_bridge_map_, LW_BRIDGE_SPAN);
        lw_bridge_map_ = nullptr;
    }
    if (fd_ >= 0) {
        close(fd_);
        fd_ = -1;
    }
    is_initialized_ = false;
    if (debug_) printf("[Cleanup] FPGA PIO API cleaned up\n");
}

PioStatus FpgaPioApi::readStatus() const {
    PioStatus status{};
    if (!bridge_map_) return status;

    auto status_ptr = reinterpret_cast<volatile uint32_t*>(lw_bridge_map_ + PIO_STATUS);
    uint32_t value = *status_ptr;

    status.raw = value;

    // Bit layout from Verilog
    status.pio_out_ready = !(value & (1 << 0));                     // Bit 0
    status.pio_in_valid = !((value >> 1) & 0x1);                   // Bit 1
    status.busy = (value >> 2) & 0x1;                      // Bit 2 → BUSY
    status.result_ready = (value >> 3) & 0x1;                      // Bit 3
    status.error_flag = (value >> 4) & 0x1;                      // Bit 4
    status.fsm_state = (value >> 6) & 0xF;                      // Bits 9:6 (4 bits)
    status.images_processed = (value >> 10) & 0xFF;                    // Bits 17:10 (8 bits)
    status.images_with_digits = (value >> 18) & 0xFF;                    // Bits 25:18 (8 bits)

    return status;
}

bool FpgaPioApi::waitForOutReady() {
    for (uint32_t tries = 0; tries < timeout_cycles_; ++tries) {
        auto status = readStatus();
        if (status.pio_out_ready) return true;
        usleep(1000);
    }
    if (debug_) fprintf(stderr, "[Timeout] OUT not ready\n");
    return false;
}

bool FpgaPioApi::waitForInValid() {
    for (uint32_t tries = 0; tries < timeout_cycles_; ++tries) {
        auto status = readStatus();
        if (status.pio_in_valid) return true;
        usleep(1000);
    }
    if (debug_) fprintf(stderr, "[Timeout] IN not valid\n");
    return false;
}

bool FpgaPioApi::write128(const std::vector<uint8_t>& word) {
    if (!bridge_map_ || word.size() != 16) return false;
    if (!unsafe_mode_ && !waitForOutReady()) return false;

    volatile uint32_t* out_ptr = reinterpret_cast<volatile uint32_t*>(bridge_map_ + PIO_OUT_BASE);

    uint32_t w0 = *reinterpret_cast<const uint32_t*>(&word[0]);
    uint32_t w1 = *reinterpret_cast<const uint32_t*>(&word[4]);
    uint32_t w2 = *reinterpret_cast<const uint32_t*>(&word[8]);
    uint32_t w3 = *reinterpret_cast<const uint32_t*>(&word[12]);

    __sync_synchronize();        // Memory barrier before write

    out_ptr[0] = w0;
    out_ptr[1] = w1;
    out_ptr[2] = w2;
    out_ptr[3] = w3;

    __sync_synchronize();        // Ensure all writes reach system bus

    asm volatile("dsb sy");   // Data Synchronization Barrier
    return true;
}


bool FpgaPioApi::writeBurst128(const std::vector<std::vector<uint8_t>>& burst_data, size_t expected_words) {
    if (!unsafe_mode_) {
        if (!waitForOutReady()) return false;

        if (burst_data.size() != expected_words) {
            if (debug_) {
                fprintf(stderr, "[ERROR] Mismatched burst length: expected %zu, got %zu\n",
                    expected_words, burst_data.size());
            }
            return false;
        }
    }

    auto out_ptr = bridge_map_ + PIO_OUT_BASE;

    for (size_t i = 0; i < burst_data.size(); ++i) {
        const auto& word = burst_data[i];

        if (word.size() != word_size) {
            if (debug_) {
                fprintf(stderr, "[ERROR] Invalid word size at index %zu (expected %zu)\n", i, word_size);
            }
            return false;
        }

        std::memcpy((void*)out_ptr, word.data(), word_size);
    }

    if (debug_) {
        printf("[INFO] writeBurst128: sent %zu 128-bit words (fast single-check mode)\n", burst_data.size());
    }

    return true;
}


bool FpgaPioApi::read128(std::vector<uint8_t>& word_out) {
    constexpr size_t word_size = 16;
    if (!bridge_map_) return false;
    if (!unsafe_mode_)
        if (!waitForInValid()) return false;

    word_out.resize(word_size);
    auto in_ptr = bridge_map_ + PIO_IN_BASE;
    std::memcpy(word_out.data(), (const void*)in_ptr, word_size);
    return true;


}



bool FpgaPioApi::readBurst128(std::vector<std::vector<uint8_t>>& burst_data, size_t expected_words) {
    constexpr size_t word_size = 16;
    burst_data.clear();
    burst_data.reserve(expected_words);

    if (!bridge_map_) return false;

    if (!unsafe_mode_) {
        if (!waitForInValid()) return false;
    }

    volatile uint32_t* in_ptr = reinterpret_cast<volatile uint32_t*>(bridge_map_ + PIO_IN_BASE);

    for (size_t i = 0; i < expected_words; ++i) {
        std::vector<uint8_t> word(word_size);

        __sync_synchronize(); // Memory barrier before read

        uint32_t w0 = in_ptr[0];
        uint32_t w1 = in_ptr[1];
        uint32_t w2 = in_ptr[2];
        uint32_t w3 = in_ptr[3];

        __sync_synchronize(); // Memory barrier after read
        asm volatile("dsb sy");

        std::memcpy(&word[0], &w0, 4);
        std::memcpy(&word[4], &w1, 4);
        std::memcpy(&word[8], &w2, 4);
        std::memcpy(&word[12], &w3, 4);

        burst_data.push_back(std::move(word));
    }

    if (debug_) {
        printf("[INFO] readBurst128: received %zu 128-bit words (fast single-check mode)\n", burst_data.size());
    }

    return true;
}

void FpgaPioApi::writeCmd(uint32_t cmd) {
    if (!lw_bridge_map_) return;
    auto cmd_ptr = reinterpret_cast<volatile uint32_t*>(lw_bridge_map_ + CMD_BASE);
    *cmd_ptr = cmd;
}
