#include "pio_interface.hpp"
#include <iostream>
#include <array>

int main()
{
    fpga::PioDevice dev;                     // 100 ms default timeout

    /* ----- send a vector of int16_t -------------------------------------- */
    std::array<int16_t, 32> line16 {};
    for (std::size_t i = 0; i < line16.size(); ++i) line16[i] = static_cast<int16_t>(i * 10);

    if (auto ec = dev.send(std::span<const int16_t>(line16)); ec) {
        std::cerr << "int16 burst failed: " << ec.message() << '\n';
        return 1;
    }

    /* ----- send an “image row” of int8_t --------------------------------- */
    std::vector<int8_t> row8(256, 42);
    dev.send(std::span<const int8_t>(row8));

    /* ----- send an OCR string block -------------------------------------- */
    dev.sendStrings({"AB123CD", "EF456GH", "IJ789KL"});

    /* ----- kick the FPGA pipeline ---------------------------------------- */
    dev.sendCommand(0x1);

    /* ----- read eight 16‑bit results back -------------------------------- */
    std::array<int16_t, 8> results {};
    if (auto ec = dev.receive(std::span<int16_t>(results)); ec) {
        std::cerr << "read failed: " << ec.message() << '\n';
        return 1;
    }

    std::cout << "FPGA returned:";
    for (auto v : results) std::cout << ' ' << v;
    std::cout << '\n';
}
