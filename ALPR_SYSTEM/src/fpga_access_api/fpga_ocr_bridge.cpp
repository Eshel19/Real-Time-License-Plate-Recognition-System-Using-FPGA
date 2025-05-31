// fpga_ocr_bridge.cpp
#include "fpga_ocr_bridge.hpp"
#include <cstring>
#include <cstdio>
#include <iostream>
#include <chrono>


namespace {
    const std::vector<std::string> default_fsm_decode = {
        "OFFLINE", "IDLE", "ACK_BP", "ACK_STRIP",
        "PROCESS_IMAGE", "NEXT_IMAGE", "NEXT_IMAGE_VALID", "WAIT_POST_RX",
        "WAIT_RAM_STORED", "WAIT_TX", "WAIT_ACK", "ERROR_RX",
        "ERROR_TX", "ERROR_COM", "ERROR_OCR", "ERROR_OVERFLOW"
    };
}

std::string FpgaOcrBridge::getFsmStateName(FsmState state) const {
    uint8_t index = static_cast<uint8_t>(state);
    const auto& decode = fsm_decode_table_.empty() ? default_fsm_decode : fsm_decode_table_;
    if (index < decode.size()) return decode[index];
    return "UNKNOWN";
}

std::string FpgaOcrBridge::getStatusString() const {
    auto status = getStatus();
    std::string result;
    std::string binary_raw;
    for (int i = 31; i >= 0; --i) {
        binary_raw += ((status.raw >> i) & 0x1) ? '1' : '0';
        if (i % 4 == 0 && i != 0) binary_raw += ' ';
    }
    result += "RAW BIN: " + binary_raw + "\n";
    result += "API MMAP is "+ initialized_ ? "online\n" : "offline\n";
    result += status.pio_out_ready ? "PIO_OUT: READY\n" : "PIO_OUT: BLOCKED\n";
    result += status.pio_in_valid ? "PIO_IN: VALID\n" : "PIO_IN: BLOCKED\n";
    result += status.result_ready ? "Rsult ready\n" : "No result\n";
    result += status.irq_active ? "IRQ: ACTIVE\n" : "IRQ: INACTIVE\n";
    result += status.error_flag ? "ERROR: TRUE\n" : "ERROR: FALSE\n";
    result += "FSM: " + getFsmStateName(status.fsm_state) + "\n";
    result += "Images Processed: " + std::to_string(status.images_processed) + "\n";
    result += "Images with Digits: " + std::to_string(status.images_with_digits);
    return result;
}

void FpgaOcrBridge::printStatus() const {
    printf("%s\n", getStatusString().c_str());
}


FpgaOcrBridge::FpgaOcrBridge(uint32_t timeout_cycles, bool debug, bool unsafe_mode)
    : core_api_(timeout_cycles, debug, unsafe_mode), debug_(debug), unsafe_mode_(unsafe_mode){
    initialized_ = core_api_.initialize();
}

FpgaOcrBridge::~FpgaOcrBridge() {
    if (initialized_) {
        cmdReset();
        core_api_.cleanup();
    }
}

bool FpgaOcrBridge::sendRawCommand(CmdType cmd_type, uint32_t payload) {
    uint32_t cmd = ((static_cast<uint8_t>(cmd_type) & 0xF) << 28) | (payload & 0x0FFFFFFF);
    core_api_.writeCmd(cmd);
    if (debug_) printf("[CMD] Sent 0x%08X\n", cmd);
    return true;
}


bool FpgaOcrBridge::cmdInit(uint8_t min_digits, uint8_t max_digits,
    uint8_t watchdog_pio, uint8_t watchdog_ocr,
    bool ocr_break, bool ignore_invalid_cmd) {
    if (min_digits > 15 || max_digits > 15 || watchdog_pio > 255 || watchdog_ocr > 255)
        return false;  // invalid inputs

    uint32_t payload = 0;
    payload |= (max_digits & 0xF) << 24;           // bits 27:24
    payload |= (min_digits & 0xF) << 20;           // bits 23:20
    payload |= (watchdog_pio & 0xFF) << 12;        // bits 19:12
    payload |= (watchdog_ocr & 0xFF) << 4;         // bits 11:4
    payload |= (ocr_break ? 1 : 0) << 3;           // bit 3
    payload |= (ignore_invalid_cmd ? 1 : 0) << 2; // bit 2
    //payload |= (1 ? 1 : 0) << 2;  // bit 2

    return sendRawCommand(CmdType::INIT, payload);
}



bool FpgaOcrBridge::cmdUpload(uint8_t image_count, uint32_t total_strip_length) {
    if (!initialized_) return false;
    if (image_count > 255 || total_strip_length > 0xFFFF) return false;

    uint32_t payload = 0;
    payload |= (total_strip_length & 0xFFFF) << 12;  // bits 27:12
    payload |= (image_count & 0xFF) << 4;            // bits 11:4
    // bits [3:0] = reserved = 0

    return sendRawCommand(CmdType::UPLOAD, payload);
}


bool FpgaOcrBridge::cmdAckIrq() {
    if (!initialized_) return false;
    return sendRawCommand(CmdType::ACK_IRQ, 0);
}

bool FpgaOcrBridge::cmdReset() {
    if (!initialized_) return false;
    bool success = sendRawCommand(CmdType::RESET, 0);
    //core_api_.cleanup();
    return success;
}

FpgaOcrBridge::OcrStatus FpgaOcrBridge::getStatus() const {
    auto raw = core_api_.readStatus();
    OcrStatus status{};

    status.raw = raw.raw;
    status.pio_out_ready = raw.pio_out_ready;
    status.pio_in_valid = raw.pio_in_valid;
    status.result_ready = raw.result_ready;
    status.irq_active = raw.busy;
    status.error_flag = raw.error_flag;
    status.fsm_state = static_cast<FsmState>(raw.fsm_state);
    status.images_processed = raw.images_processed;
    status.images_with_digits = raw.images_with_digits;
    return status;
}




bool FpgaOcrBridge::sendImageStrip(std::vector<std::vector<std::vector<uint8_t>>>& images_u8) {
    if (!initialized_) return false;

    auto t0 = std::chrono::high_resolution_clock::now();

    const size_t height = 16;
    size_t total_width = 0;
    std::vector<uint16_t> breakpoints;

    // Step 1: validate and calculate breakpoints
    for (const auto& img : images_u8) {
        if (img.size() != height) return false;
        size_t w = img[0].size();
        for (const auto& row : img) {
            if (row.size() != w) return false;
        }
        total_width += w;
        breakpoints.push_back(static_cast<uint16_t>(total_width - 1));
    }

    // Step 2: prepare normalized strip in [column][row]
    std::vector<int8_t> strip_flat(total_width * height);
    size_t x_offset = 0;

    for (const auto& img : images_u8) {
        const size_t w = img[0].size();
        for (size_t y = 0; y < height; ++y) {
            const uint8_t* src_row = img[y].data();
            for (size_t x = 0; x < w; ++x) {
                strip_flat[(x_offset + x) * height + y] = static_cast<int8_t>(src_row[x] - 128);
            }
        }
        x_offset += w;
    }

    auto t1 = std::chrono::high_resolution_clock::now();

    // Send command
    if (!cmdUpload(static_cast<uint8_t>(images_u8.size()), static_cast<uint32_t>(total_width))) {
        if (debug_) fprintf(stderr, "[ERROR] Upload command failed.\n");
        return false;
    }

    auto t2 = std::chrono::high_resolution_clock::now();

    // Send breakpoints
    if (!sendUint16Array(breakpoints)) {
        if (debug_) fprintf(stderr, "[ERROR] Sending breakpoints failed.\n");
        return false;
    }

    auto t3 = std::chrono::high_resolution_clock::now();

    // Send image data
    if (!sendImageColumnsFlat(strip_flat)) {
        if (debug_) fprintf(stderr, "[ERROR] Sending image columns failed.\n");
        return false;
    }

    auto t4 = std::chrono::high_resolution_clock::now();

    if (debug_) {
        double preprocess_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
        double upload_cmd_ms = std::chrono::duration<double, std::milli>(t2 - t1).count();
        double send_bp_ms = std::chrono::duration<double, std::milli>(t3 - t2).count();
        double send_strip_ms = std::chrono::duration<double, std::milli>(t4 - t3).count();
        double total_ms = std::chrono::duration<double, std::milli>(t4 - t0).count();

        printf("[TIMER] Preprocess:       %.3f ms\n", preprocess_ms);
        printf("[TIMER] Send cmdUpload:   %.3f ms\n", upload_cmd_ms);
        printf("[TIMER] Send breakpoints: %.3f ms\n", send_bp_ms);
        printf("[TIMER] Send strip:       %.3f ms\n", send_strip_ms);
        printf("[TIMER] Total:            %.3f ms\n", total_ms);

        printf("[INFO] Sent %zu images (%zu total columns)\n", images_u8.size(), total_width);
        printf("[INFO] Breakpoints: ");
        for (uint16_t bp : breakpoints) printf("%u ", bp);
        printf("\n");
    }

    return true;
}




bool FpgaOcrBridge::isBusy() const {
    auto s = getStatus();
    return !(s.pio_out_ready && s.pio_in_valid);
}

bool FpgaOcrBridge::isBusyOut() const {
    return !getStatus().pio_out_ready;
}

bool FpgaOcrBridge::isBusyIn() const {
    return !getStatus().pio_in_valid;
}

void FpgaOcrBridge::setFsmDecodeTable(const std::vector<std::string>& decode_table) {
    fsm_decode_table_ = decode_table;
}


bool FpgaOcrBridge::waitForFsm(FsmState expected, uint32_t timeout_cycles) const {
    for (uint32_t i = 0; i < timeout_cycles; ++i) {
        if (getStatus().fsm_state == expected) return true;
    }
    return false;
}

bool FpgaOcrBridge::sendUint16Array(const std::vector<uint16_t>& values)
{
    if (!initialized_) return false;

    constexpr size_t per_word = 8;          // 8 × uint16  = 1 × 128-bit
    std::vector<std::vector<uint8_t>> packed;
    packed.reserve((values.size() + per_word - 1) / per_word);

    for (size_t i = 0; i < values.size(); i += per_word) {
        std::array<uint8_t, 16> word{};     // 16 bytes initialised to 0

        for (size_t j = 0; j < per_word && (i + j) < values.size(); ++j) {
            uint16_t v = values[i + j];
            // Little-endian inside the 128-bit lane:
            //   byte 0 = bits  7…0  of slice-0
            //   byte 1 = bits 15…8  of slice-0
            word[j * 2] = static_cast<uint8_t>(v & 0xFF);        // LSB
            word[j * 2 + 1] = static_cast<uint8_t>(v >> 8);          // MSB
        }

        // move the 16-byte block into the packet list
        packed.emplace_back(word.begin(), word.end());
    }

    return core_api_.writeBurst128(packed, packed.size());
}

bool FpgaOcrBridge::sendImageColumnsFlat(const std::vector<int8_t>& flat_strip) {
    if (!initialized_) return false;

    const size_t height = 16;

    if (flat_strip.size() % height != 0) {
        if (debug_) fprintf(stderr, "[ERROR] Flat strip size (%zu) not divisible by height (%zu)\n", flat_strip.size(), height);
        return false;
    }

    const size_t total_columns = flat_strip.size() / height;

    std::vector<std::vector<uint8_t>> packed;
    packed.reserve(total_columns);

    for (size_t col = 0; col < total_columns; ++col) {
        std::vector<uint8_t> word(16, 0);
        for (size_t row = 0; row < height; ++row) {
            int8_t val = flat_strip[col * height + row];
            word[15 - row] = static_cast<uint8_t>(val);
        }

        packed.push_back(std::move(word));
    }

    if (debug_) {
        std::cout << "[DEBUG] Image columns packed (flat): " << packed.size() << " words\n";
    }

    return core_api_.writeBurst128(packed, packed.size());
}





bool FpgaOcrBridge::sendImageColumns(const std::vector<std::vector<int8_t>>& columns) {
    if (!initialized_) return false;

    std::vector<std::vector<uint8_t>> packed;
    for (const auto& col : columns) {
        std::vector<uint8_t> word(16, 0);
        for (size_t i = 0; i < std::min<size_t>(16, col.size()); ++i) {
            word[i] = static_cast<uint8_t>(col[i]);  // reinterpret INT8 as raw byte
        }
        packed.push_back(std::move(word));
    }
    if (debug_) {
        std::cout << "[DEBUG] Image columns packed: " << packed.size() << " words\n";
    }
    return core_api_.writeBurst128(packed, packed.size());
}

bool FpgaOcrBridge::receiveResultStrings(std::vector<std::string>& results_out) {
    results_out.clear();
    if (!initialized_) return false;

    // 1. Read the 16-byte header: first byte is count
    std::vector<uint8_t> header;
    if (!core_api_.read128(header)) return false;
    if (header.size() < 1) return false;
    uint8_t count = header[0];
    if (debug_) {
        printf("[DEBUG] Header (first 16 bytes):");
        for (size_t i = 0; i < header.size(); ++i)
            printf(" a[%zu]=%02x", i, header[i]);
        printf("\n");
        printf("[DEBUG] Burst word count (header[0]): %u\n", count);
    }
    if (count == 0) return true; // nothing to read

    // 2. Read count 128-bit (16-byte) words in a burst
    std::vector<std::vector<uint8_t>> raw_data;
    if (!core_api_.readBurst128(raw_data, count)) return false;

    // 3. Parse the burst into strings, split on '\0'
    std::string buffer;
    for (const auto& word : raw_data) {
        for (uint8_t c : word) {
            if (c == '\0') {
                if (!buffer.empty()) {
                    results_out.push_back(buffer);
                    buffer.clear();
                }
                // else: ignore repeated or leading nulls
            }
            else {
                buffer += static_cast<char>(c);
            }
        }
    }
    // Don't push buffer if not terminated by '\0'
    return true;
}


bool FpgaOcrBridge::sendRawColumn(const std::vector<uint8_t>& word) {
    return core_api_.write128(word);
}

