// pio_interface.hpp — High‑level OCR PIO wrapper (Dual‑bridge version)
// -----------------------------------------------------------------------------
// 2025 ‑ MIT License – use at your own risk.
// Requires: C++17, fpga_pio_api.hpp in include path.
//
//  ┌───────────────────────────────┐  HPS‑to‑FPGA (H2F) main bridge  
//  │ 0xC000_0000 + 0x0000  PIO128_OUT   (128‑bit write FIFO)         
//  │                + 0x0010  PIO128_IN    (128‑bit read FIFO)       
//  │                + 0x0020  PIO_STATUS   (32‑bit read‑only)        
//  └───────────────────────────────┘
//  ┌───────────────────────────────┐  HPS‑to‑FPGA‑LW (light‑weight)  
//  │ 0xFF20_0000 + 0x0000  PIO_COMMAND  (32‑bit write‑only)          
//  └───────────────────────────────┘
//
//  Change the two bridge base addresses below if your Quartus system uses
//  different windows, or override them with -DMAIN_BRIDGE_BASE=... and/or
//  -DLW_BRIDGE_BASE=... at compile time.
// -----------------------------------------------------------------------------

#ifndef MAIN_BRIDGE_BASE
#   define MAIN_BRIDGE_BASE 0xC0000000UL   // default H2F window (64 MiB)
#endif
#ifndef LW_BRIDGE_BASE
#   define LW_BRIDGE_BASE   0xFF200000UL   // default LW window  (1  MiB)
#endif

// Offsets inside the MAIN bridge
#define PIO128_OUT_OFFSET   0x0000
#define PIO128_IN_OFFSET    0x0010
#define PIO_STATUS_OFFSET   0x0020

// Absolute addresses (compile‑time constants)
#define PIO128_OUT_BASE   (MAIN_BRIDGE_BASE + PIO128_OUT_OFFSET)
#define PIO128_IN_BASE    (MAIN_BRIDGE_BASE + PIO128_IN_OFFSET)
#define PIO_STATUS_BASE   (MAIN_BRIDGE_BASE + PIO_STATUS_OFFSET)

// PIO_COMMAND sits alone in the LW bridge at offset 0
#define PIO_COMMAND_BASE  (LW_BRIDGE_BASE)

// -----------------------------------------------------------------------------
//  Include low‑level mapper AFTER the address macros are defined.
// -----------------------------------------------------------------------------
#include "fpga_pio_api.hpp"

#include <vector>
#include <string>
#include <span>
#include <system_error>
#include <chrono>
#include <cstdint>

namespace fpga {

/* ------------------------------------------------------------------------- */
/*  Command format helpers (PIO_COMMAND, 32‑bit write‑only)                  */
/* ------------------------------------------------------------------------- */
enum class CmdType : uint8_t {
    INIT      = 0x1,
    UPLOAD    = 0x2,
    ACK_IRQ   = 0x3,
    RESET     = 0xF
};

inline constexpr uint32_t packCommand(CmdType type, uint32_t payload = 0)
{
    return (static_cast<uint32_t>(type) << 28) | (payload & 0x0FFFFFFF);
}

// –– high‑level helpers ––
inline constexpr uint32_t makeInitCmd(uint8_t min_digits, uint8_t max_digits)
{
    uint32_t payload = ((min_digits & 0x0F) << 24) | ((max_digits & 0x0F) << 20);
    return packCommand(CmdType::INIT, payload);
}
inline constexpr uint32_t makeUploadCmd(uint8_t image_count, uint32_t strip_len_cols)
{
    uint32_t payload = ((image_count & 0xFF) << 20) | (strip_len_cols & 0x000FFFFF);
    return packCommand(CmdType::UPLOAD, payload);
}
inline constexpr uint32_t makeAckIrqCmd() { return packCommand(CmdType::ACK_IRQ); }
inline constexpr uint32_t makeResetCmd()  { return packCommand(CmdType::RESET);  }

/* ------------------------------------------------------------------------- */
/*  Status register decoding (PIO_STATUS, 32‑bit read‑only)                  */
/* ------------------------------------------------------------------------- */
struct Status {
    bool     busy          = false;  // bit 0
    bool     irq_active    = false;  // bit 1
    bool     error_flag    = false;  // bit 2
    uint8_t  fsm_state     = 0;      // bits 7:3
    uint8_t  images_processed   = 0; // bits 15:8
    uint8_t  images_with_digits = 0; // bits 23:16
};

class PioStatus : private PioReg32 {
public:
    explicit PioStatus(std::chrono::milliseconds timeout)
        : PioReg32(PIO_STATUS_BASE, timeout) {}

    Status read() const {
        uint32_t v = *reg_.ptr32();
        Status s;
        s.busy              = v & 0x1;
        s.irq_active        = v & 0x2;
        s.error_flag        = v & 0x4;
        s.fsm_state         = static_cast<uint8_t>((v >> 3) & 0x1F);
        s.images_processed  = static_cast<uint8_t>((v >> 8) & 0xFF);
        s.images_with_digits= static_cast<uint8_t>((v >> 16) & 0xFF);
        return s;
    }
};

/* ------------------------------------------------------------------------- */
/*  Single façade class that glues everything together                       */
/* ------------------------------------------------------------------------- */
class PioDevice {
public:
    explicit PioDevice(std::chrono::milliseconds timeout = std::chrono::milliseconds{100})
        : out_{timeout}, in_{timeout}, cmd_{timeout}, st_{timeout} {}

    /* ---------- Streaming data (any POD buffer) ------------------------- */
    template <typename T>
    std::error_code send(std::span<const T> data) { return out_.write(data); }

    template <typename T>
    std::error_code receive(std::span<T> dest)    { return in_.read(dest);   }

    /* ---------- Command helpers ---------------------------------------- */
    std::error_code init(uint8_t min_digits, uint8_t max_digits) {
        return cmd_.writeWord(makeInitCmd(min_digits, max_digits));
    }
    std::error_code upload(uint8_t img_count, uint32_t strip_len_cols) {
        return cmd_.writeWord(makeUploadCmd(img_count, strip_len_cols));
    }
    std::error_code ackIrq()   { return cmd_.writeWord(makeAckIrqCmd()); }
    std::error_code reset()    { return cmd_.writeWord(makeResetCmd());  }

    /* ---------- Status -------------------------------------------------- */
    Status status() const { return st_.read(); }

private:
    Pio128Out  out_;
    Pio128In   in_;
    PioCommand cmd_;
    PioStatus  st_;
};

} // namespace fpga
