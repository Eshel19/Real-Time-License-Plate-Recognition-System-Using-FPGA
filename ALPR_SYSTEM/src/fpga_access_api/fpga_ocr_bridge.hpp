// fpga_ocr_bridge.hpp
#pragma once

#include "fpga_pio_api.hpp"
#include <vector>
#include <string>
#include <cstdint>
#include <array>
class FpgaOcrBridge {
public:
    enum class CmdType : uint8_t {
        INIT = 0b0001,
        UPLOAD = 0b0010,
        ACK_IRQ = 0b0100,
        RESET = 0b1000
    };

    enum class FsmState : uint8_t {
        OFFLINE = 0,
        IDLE = 1,
        ACK_BP = 2,
        ACK_STRIP = 3,
        PROCESS_IMAGE = 4,
        NEXT_IMAGE = 5,
        NEXT_IMAGE_VALID = 6,
        WAIT_POST_RX = 7,
        WAIT_RAM_STORED = 8,
        WAIT_TX = 9,
        WAIT_ACK = 10,
        // Error states start here (for clear separation)
        ERROR_RX = 11,
        ERROR_TX = 12,
        ERROR_COM = 13,
        ERROR_OCR = 14,
        ERROR_OVERFLOW = 15
    };

    struct OcrStatus {
        uint32_t raw;
        bool pio_out_ready;
        bool pio_in_valid;
        bool result_ready;
        bool irq_active;
        bool error_flag;
        FsmState fsm_state;
        uint8_t images_processed;
        uint8_t images_with_digits;
    };

    const std::vector<std::string> default_fsm_decode = {
        "OFFLINE", "IDLE", "ACK_BP", "ACK_STRIP",
        "PROCESS_IMAGE", "NEXT_IMAGE", "NEXT_IMAGE_VALID", "WAIT_POST_RX",
        "WAIT_RAM_STORED", "WAIT_TX", "WAIT_ACK", "ERROR_RX",
        "ERROR_TX", "ERROR_COM", "ERROR_OCR", "ERROR_OVERFLOW"
    };

    explicit FpgaOcrBridge(uint32_t timeout_cycles = 1000, bool debug = false, bool unsafe_mode= false);
    ~FpgaOcrBridge();



    // Command Interface
    bool cmdInit(uint8_t min_digits, uint8_t max_digits,
        uint8_t watchdog_pio, uint8_t watchdog_ocr,
        bool ocr_break, bool ignore_invalid_cmd);
    bool cmdUpload(uint8_t image_count, uint32_t total_strip_length);
    bool cmdAckIrq();
    bool cmdReset();

    // Status
    OcrStatus getStatus() const;
    bool waitForFsm(FsmState expected, uint32_t timeout_cycles) const;
    bool isBusy() const;
    bool isBusyOut() const;
    bool isBusyIn() const;
    void setFsmDecodeTable(const std::vector<std::string>& decode_table);

    std::string getFsmStateName(FsmState state) const;
    std::string getStatusString() const;
    void printStatus() const;

    // Data Send
    bool sendImageStrip(std::vector<std::vector<std::vector<uint8_t>>>& images_u8);
    bool sendRawColumn(const std::vector<uint8_t>& word);

    bool sendUint16Array(const std::vector<uint16_t>& values);
    bool sendImageColumns(const std::vector<std::vector<int8_t>>& columns);

    // Receive Results
    bool receiveResultStrings(std::vector<std::string>& results_out);

private:
    bool sendRawCommand(CmdType cmd_type, uint32_t payload);
    bool sendImageColumnsFlat(const std::vector<int8_t>& flat_strip);

    fpga::FpgaPioApi core_api_;
    bool initialized_ = false;
    bool debug_ = false;
    bool unsafe_mode_ = false; /*For testing only this skip waitrequest test from status before trying to read/write to the PIO*/
    std::vector<std::string> fsm_decode_table_;
};
