// ──────────────────────────────────────────────  ocr_bridge.hpp  ──
#pragma once

#include "pio_interface.hpp"          // owns dual‑bridge PioDevice
#include <span>
#include <vector>
#include <string>
#include <system_error>

namespace ocr {

/*  High‑level façade – only OCR‑specific operations.                */
class Bridge {
public:
    explicit Bridge(std::chrono::milliseconds t = std::chrono::milliseconds{100})
        : dev_{t} {}

    /* ---------- configuration + metadata -------------------------- */
    void configure(uint8_t min_digits, uint8_t max_digits) {
        dev_.init(min_digits, max_digits);
    }

    void uploadInfo(uint8_t image_count, uint32_t strip_len_cols) {
        dev_.upload(image_count, strip_len_cols);
    }

    /* ---------- stream one INT8 strip (16 rows × W cols) ---------- */
    std::error_code sendFrame(std::span<const int8_t> strip) {
        return dev_.send(strip);              // packs to 128‑bit words inside
    }

    /* ---------- status / housekeeping ----------------------------- */
    fpga::Status status() const               { return dev_.status(); }
    void         ackIrq()                     { dev_.ackIrq();        }
    void         reset()                      { dev_.reset();         }

    /* ---------- two‑stage string‑block read ----------------------- */
    std::error_code readStringResults(std::vector<std::string>& out)
    {
        /* 1️⃣  header: one 128‑bit word, low byte = payload word‑count   */
        __uint128_t hdr = 0;
        if (auto ec = dev_.receive(std::span<__uint128_t>(&hdr, 1)); ec) return ec;

        uint8_t wordCount = static_cast<uint8_t>(hdr & 0xFF);   // little‑endian
        if (!wordCount) { out.clear(); return {}; }

        /* 2️⃣  payload: <wordCount> × 128‑bit words ------------------- */
        std::vector<std::uint8_t> buf(static_cast<std::size_t>(wordCount) * 16u);
        if (auto ec = dev_.receive(std::span<uint8_t>(buf)); ec) return ec;

        /* 3️⃣  split at NULs into strings ----------------------------- */
        out.clear();
        std::string cur;
        for (auto b : buf) {
            if (b == 0) {
                if (!cur.empty()) { out.emplace_back(std::move(cur)); cur.clear(); }
            } else {
                cur.push_back(static_cast<char>(b));
            }
        }
        if (!cur.empty()) out.emplace_back(std::move(cur));

        return {};
    }

private:
    fpga::PioDevice dev_;   // low‑level I/O (read/write always 128‑bit beats)
};

} // namespace ocr
// ───────────────────────────────────────────────────────────────────
