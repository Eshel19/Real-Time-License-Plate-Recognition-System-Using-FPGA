#include "ocr_bridge.hpp"
#include <iostream>
#include <vector>
#include <array>
#include <thread>
#include <chrono>

int main()
{
    /* LOW‑LEVEL: push an arbitrary uint16_t line ------------------- */
    std::array<uint16_t, 64> line16{};
    for (std::size_t i = 0; i < line16.size(); ++i) line16[i] = i;

    fpga::PioDevice raw;   // from pio_interface.hpp
    auto ec = raw.send(std::span<const uint16_t>(line16));
    if (ec) { std::cerr << "raw send failed: " << ec.message() << '\n'; return 1; }

    /* HIGH‑LEVEL: standard OCR flow via ocr::Bridge ---------------- */
    constexpr std::size_t widthCols  = 200;
    constexpr std::size_t imageCount = 16;
    std::vector<int8_t> frame(16 * widthCols, 42);   // dummy INT8 strip

    ocr::Bridge ocr;
    ocr.reset();
    ocr.configure(/*min=*/1, /*max=*/8);
    ocr.sendFrame(std::span<const int8_t>(frame));
    ocr.uploadInfo(imageCount, widthCols);

    /* wait until result ready (IRQ_ACTIVE) ------------------------- */
    while (!ocr.status().irq_active) std::this_thread::sleep_for(std::chrono::milliseconds(1));

    /* read back the string block ----------------------------------- */
    std::vector<std::string> texts;
    if (auto ec2 = ocr.readStringResults(texts); ec2) {
        std::cerr << "string read failed: " << ec2.message() << '\n';
        return 1;
    }
    ocr.ackIrq();

    std::cout << "FPGA returned " << texts.size() << " strings:\n";
    for (const auto& s : texts) std::cout << "  • \"" << s << "\"\n";
}
