#include "fpga_pio_api.hpp"
#include "fpga_pio_address.hpp"

#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <cstring>
#include <cstdio>

using namespace fpga;

FpgaPioApi::FpgaPioApi(uint32_t timeout_cycles, bool debug)
    : timeout_cycles_(timeout_cycles), debug_(debug) {
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

PioStatus FpgaPioApi::readStatus() {
    PioStatus status{};
    if (!bridge_map_) return status;

    auto status_ptr = reinterpret_cast<volatile uint32_t*>(bridge_map_ + PIO_STATUS);
    uint32_t value = *status_ptr;
    status.raw = value;
    status.pio_out_ready = !(value & 0x1);              // bit 0: 0 = ready, 1 = wait
    status.pio_in_valid = !((value >> 1) & 0x1);         // bit 1: 0 = valid
    status.irq_active = (value >> 2) & 0x1;
    status.error_flag = (value >> 3) & 0x1;
    status.fsm_state = (value >> 4) & 0xF;
    status.images_processed = (value >> 8) & 0xFF;
    status.images_with_digits = (value >> 16) & 0xFF;

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
    if (!bridge_map_ || word.size() != word_size) return false;
    if (!waitForOutReady()) return false;

    auto out_ptr = bridge_map_ + PIO_OUT_BASE;
    std::memcpy((void*)out_ptr, word.data(), word_size);
    return true;
}

bool FpgaPioApi::read128(std::vector<uint8_t>& word_out) {
    if (!bridge_map_) return false;
    if (!waitForInValid()) return false;

    word_out.resize(word_size);
    auto in_ptr = bridge_map_ + PIO_IN_BASE;
    std::memcpy(word_out.data(), (const void*)in_ptr, word_size);
    return true;
}

bool FpgaPioApi::writeBurst128(const std::vector<std::vector<uint8_t>>& burst_data) {
    if (!waitForOutReady()) return false;

    size_t total = burst_data.size();
    size_t offset = 0;

    while (offset < total) {
        size_t chunk = std::min<size_t>(8, total - offset);
        for (size_t i = 0; i < chunk; ++i) {
            const auto& word = burst_data[offset + i];
            if (word.size() != word_size) {
                if (debug_) fprintf(stderr, "[Error] Invalid word size at index %zu\n", offset + i);
                return false;
            }
            auto out_ptr = bridge_map_ + PIO_OUT_BASE;
            std::memcpy((void*)out_ptr, word.data(), word_size);
        }
        offset += chunk;
    }
    return true;
}

bool FpgaPioApi::readBurst128(std::vector<std::vector<uint8_t>>& burst_out, size_t burst_length) {
    if (!waitForInValid()) return false;

    burst_out.clear();
    size_t offset = 0;

    while (offset < burst_length) {
        size_t chunk = std::min<size_t>(8, burst_length - offset);
        for (size_t i = 0; i < chunk; ++i) {
            std::vector<uint8_t> word(word_size);
            auto in_ptr = bridge_map_ + PIO_IN_BASE;
            std::memcpy(word.data(), (const void*)in_ptr, word_size);
            burst_out.push_back(std::move(word));
        }
        offset += chunk;
    }
    return true;
}

void FpgaPioApi::writeCmd(uint32_t cmd) {
    if (!lw_bridge_map_) return;
    auto cmd_ptr = reinterpret_cast<volatile uint32_t*>(lw_bridge_map_ + CMD_BASE);
    *cmd_ptr = cmd;
}
