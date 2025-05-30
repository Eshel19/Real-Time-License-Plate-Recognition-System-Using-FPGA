#pragma once
#include "fpga_pio_api.hpp"   // ← the low‑level mapper you already have

#include <vector>
#include <string>
#include <span>
#include <system_error>
#include <chrono>

namespace fpga {

/* ---------------------------------------------------------------------------
 *  Thin façade that glues the three PIO blocks into one convenient object.
 * --------------------------------------------------------------------------*/
class PioDevice {
public:
    /// \param timeout  How long the helpers will wait for the PIO‑ready flags.
    explicit PioDevice(std::chrono::milliseconds timeout = std::chrono::milliseconds{100})
        : out_{timeout}, in_{timeout}, cmd_{timeout} {}

    /* ------------  Generic helpers (any trivially‑copyable type)  --------- */
    template <typename T>
    std::error_code send(std::span<const T> data)          { return out_.write(data); }

    template <typename T>
    std::error_code receive(std::span<T> dest)             { return in_.read(dest);   }

    /* ------------  Convenience wrappers  ---------------------------------- */
    std::error_code sendCommand(uint32_t cmd)              { return cmd_.writeWord(cmd); }

    /// Sends a list of C‑strings, separated with NUL terminators, in one burst.
    std::error_code sendStrings(const std::vector<std::string>& list)
    {
        std::vector<std::uint8_t> blob;
        for (const auto& s : list) {
            blob.insert(blob.end(), s.begin(), s.end());
            blob.push_back('\0');
        }
        return send(std::span<const std::uint8_t>(blob.data(), blob.size()));
    }

private:
    Pio128Out  out_;
    Pio128In   in_;
    PioCommand cmd_;
};

} // namespace fpga
