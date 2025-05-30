
#include "fpga_ocr_bridge.hpp"
#include <iostream>
#include <thread>
#include <chrono>
#include <opencv2/opencv.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

void printMenu() {
    std::cout << "\n=== FPGA OCR Bridge Control Menu ===\n";
    std::cout << "1. Reset FPGA\n";
    std::cout << "2. Init FPGA\n";
    std::cout << "3. Print Status\n";
    std::cout << "4. Acknowledge IRQ\n";
    std::cout << "5. Send Dummy Upload Command (Test Only)\n";
    std::cout << "6. Send dumy image to process\n";
    std::cout << "7. Receive OCR Result Strings\n";
    std::cout << "8. Send Manual Breakpoints Only\n";
    std::cout << "9. Send Manual Images (Interactive Width)\n";
    std::cout << "10. Load and Send Real Image (OpenCV)\n";

    std::cout << "0. Exit\n";
    std::cout << "Choose an option: ";
}

int main() {
    FpgaOcrBridge bridge(1000, true,false);

    int choice = -1;
    while (true) {
        printMenu();

        if (!(std::cin >> choice)) {
            std::cin.clear(); // clear bad input flag
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n'); // discard input
            std::cout << "Invalid input. Please enter a number.\n";
            continue;
        }

        switch (choice) {
        case 1:
            std::cout << "\n[Running RESET]\n";
            if (bridge.cmdReset())
                std::cout << "Reset command sent successfully.\n";
            else
                std::cout << "Failed to send reset command.\n";
            bridge.printStatus();
            break;

        case 2: {
            std::cout << "\n[Running INIT with user-defined values]\n";

            int min_digits = 0, max_digits = 0, wdog_pio = 0, wdog_ocr = 0;
            char ocr_break = 'n', ignore_invalid = 'n';

            std::cout << "Enter MIN_DIGITS (0–15): ";
            std::cin >> min_digits;
            std::cout << "Enter MAX_DIGITS (0–15): ";
            std::cin >> max_digits;
            std::cout << "Enter WATCHDOG_PIO (0–255): ";
            std::cin >> wdog_pio;
            std::cout << "Enter WATCHDOG_OCR (0–255): ";
            std::cin >> wdog_ocr;
            std::cout << "Enable OCR_BREAK mode? (y/n): ";
            std::cin >> ocr_break;
            std::cout << "Ignore invalid commands? (y/n): ";

            std::cin >> ignore_invalid;

            bool break_flag = (ocr_break == 'y' || ocr_break == 'Y');
            bool ignore_flag = (ignore_invalid == 'y' || ignore_invalid == 'Y');

            if (bridge.cmdInit(min_digits, max_digits, wdog_pio, wdog_ocr, break_flag, ignore_flag))
                std::cout << "Init command sent successfully.\n";
            else
                std::cout << "Failed to send init command (bad values?).\n";

            bridge.printStatus();
            break;
        }
        case 3:
            std::cout << "\n[Current FPGA Status]\n";
            bridge.printStatus();
            break;

        case 4:
            std::cout << "\n[Running ACK_IRQ]\n";
            if (bridge.cmdAckIrq())
                std::cout << "ACK_IRQ sent successfully.\n";
            else
                std::cout << "Failed to send ACK_IRQ.\n";
            bridge.printStatus();
            break;
        case 5: {
            std::cout << "\n[TEST: Send Dummy UPLOAD Command]\n";

            uint32_t strip_len = 0;
            uint32_t bp_count = 0;

            std::cout << "Enter total strip length (max 65535): ";
            std::cin >> strip_len;

            std::cout << "Enter number of breakpoints (images, max 255): ";
            std::cin >> bp_count;

            if (strip_len > 0xFFFF || bp_count > 0xFF) {
                std::cout << "[ERROR] Invalid input values.\n";
                break;
            }

            if (!bridge.cmdUpload(static_cast<uint8_t>(bp_count), strip_len)) {
                std::cout << "[ERROR] Upload command failed.\n";
                break;
            }

            std::cout << "[INFO] Upload command sent.\n";
            bridge.printStatus();
            break;
        }

        case 6: {
            std::vector<std::vector<std::vector<uint8_t>>> imgs;
            for (int i = 0; i < 10; ++i) {
                std::vector<std::vector<uint8_t>> img(16, std::vector<uint8_t>(300, 50 + i * 10));
                imgs.push_back(img);
            }

            std::cout << "[INFO] Sending 10 images, each 16x300...\n";

            auto t_start = std::chrono::high_resolution_clock::now();

            if (!bridge.sendImageStrip(imgs)) {
                std::cout << "Failed to send image strip with breakpoints.\n";
                break;
            }

            auto t_send_done = std::chrono::high_resolution_clock::now();

            constexpr FpgaOcrBridge::FsmState WAIT_ACK = FpgaOcrBridge::FsmState::WAIT_ACK;
            if (!bridge.waitForFsm(WAIT_ACK, 1'000'000)) {
                std::cout << "Timed out waiting for WAIT_ACK state.\n";
                break;
            }

            auto t_fsm_done = std::chrono::high_resolution_clock::now();

            double send_time_ms = std::chrono::duration<double, std::milli>(t_send_done - t_start).count();
            double total_time_ms = std::chrono::duration<double, std::milli>(t_fsm_done - t_start).count();

            std::cout << "✅ Image strip sent in " << send_time_ms << " ms\n";
            std::cout << "✅ System reached WAIT_ACK in " << total_time_ms << " ms\n";

            bridge.printStatus();
            break;
        }



        case 7: {
            std::vector<std::string> results;
            std::cout << "\n[Receiving Result Strings from FPGA...]\n";

            if (!bridge.receiveResultStrings(results)) {
                std::cout << "[ERROR] Failed to receive result strings.\n";
                break;
            }

            if (results.empty()) {
                std::cout << "[INFO] No result strings received.\n";
            }
            else {
                std::cout << "[INFO] Received " << results.size() << " result(s):\n";
                for (size_t i = 0; i < results.size(); ++i) {
                    const auto& str = results[i];

                    if (str.empty()) {
                        std::cout << "  [" << i << "]: <EMPTY>\n";
                    }
                    else if (str.front() == '\0') {
                        std::cout << "  [" << i << "]: <PADDING OR NULL>\n";
                    }
                    else {
                        std::cout << "  [" << i << "]: \"" << str << "\"\n";
                    }
                }
            }

            break;
        }
        case 8: {
            std::cout << "\n[TEST] Send manual breakpoints\n";
            size_t count = 0;
            std::cout << "Enter number of breakpoints: ";
            std::cin >> count;

            std::vector<uint16_t> breakpoints;
            uint16_t total = 0;
            for (size_t i = 0; i < count; ++i) {
                uint16_t w;
                std::cout << "  Enter width for image " << i << ": ";
                std::cin >> w;
                total += w;
                breakpoints.push_back(total - 1);
            }

            std::cout << "[INFO] Sending breakpoints: ";
            for (auto bp : breakpoints) std::cout << bp << " ";
            std::cout << "\n";

            if (!bridge.sendUint16Array(breakpoints)) {
                std::cout << "[ERROR] Failed to send breakpoints\n";
            }
            else {
                std::cout << "[SUCCESS] Breakpoints sent.\n";
            }

            break;
        }
        case 9: {
            std::cout << "\n[TEST] Send image strip line-by-line (watch FSM)\n";

            size_t image_count = 0;
            std::cout << "Enter number of images: ";
            std::cin >> image_count;

            std::vector<std::vector<std::vector<uint8_t>>> images;
            size_t total_width = 0;

            for (size_t i = 0; i < image_count; ++i) {
                size_t width = 0;
                std::cout << "  Enter width for image " << i << ": ";
                std::cin >> width;
                total_width += width;

                std::vector<std::vector<uint8_t>> img(16, std::vector<uint8_t>(width));
                for (size_t y = 0; y < 16; ++y) {
                    for (size_t x = 0; x < width; ++x) {
                        img[y][x] = static_cast<uint8_t>(128 + (i * 20));  // synthetic values
                    }
                }
                images.push_back(std::move(img));
            }

            // Flatten images into strip[col][row]
            std::vector<std::vector<uint8_t>> strip;
            strip.reserve(total_width);
            size_t x_offset = 0;
            for (const auto& img : images) {
                size_t w = img[0].size();
                for (size_t x = 0; x < w; ++x) {
                    std::vector<uint8_t> col(16, 0);
                    for (size_t y = 0; y < 16; ++y) {
                        col[y] = img[y][x];
                    }
                    strip.push_back(col);
                }
            }

            // Send columns one by one, count accepted words
            size_t sent = 0;
            for (const auto& word : strip) {
                bool ok = bridge.sendRawColumn(word);
                if (!ok) {
                    std::cout << "[HALT] sendRawColumn() failed at index " << sent << "\n";
                    break;
                }

                ++sent;

                auto status = bridge.getStatus();
                if (sent % 1 == 0) {  // print every word
                    std::cout << "[INFO] Sent " << sent << " | FSM: " << bridge.getFsmStateName(status.fsm_state)
                        << " | OUT: " << (status.pio_out_ready ? "READY" : "BLOCKED")
                        << " | ERR: " << (status.error_flag ? "TRUE" : "FALSE") << "\n";
                }

                if (status.error_flag && status.fsm_state == FpgaOcrBridge::FsmState::ERROR_RX) {
                    std::cout << "[ERROR] FPGA entered ERROR_RX at " << sent << "\n";
                    break;
                }
            }
            break;
        }

        case 10: {
            std::cout << "\n[TEST] Load and send real image multiple times\n";

            std::string filename;
            int copies = 1;

            std::cout << "Enter image path: ";
            std::cin >> filename;

            std::cout << "Enter number of copies to send: ";
            std::cin >> copies;
            if (copies <= 0) {
                std::cout << "[ERROR] Invalid copy count.\n";
                break;
            }

            // Load image
            cv::Mat img = cv::imread(filename, cv::IMREAD_GRAYSCALE);
            if (img.empty()) {
                std::cout << "[ERROR] Failed to load image: " << filename << "\n";
                break;
            }

            // Resize to 16 rows
            int orig_cols = img.cols;
            cv::resize(img, img, cv::Size(orig_cols, 16), 0, 0, cv::INTER_LINEAR);

            // Convert to vector<image> format
            std::vector<std::vector<std::vector<uint8_t>>> images;

            for (int copy = 0; copy < copies; ++copy) {
                std::vector<std::vector<uint8_t>> single_img(16, std::vector<uint8_t>(orig_cols));
                for (int y = 0; y < 16; ++y) {
                    for (int x = 0; x < orig_cols; ++x) {
                        single_img[y][x] = img.at<uint8_t>(y, x);
                    }
                }
                images.push_back(std::move(single_img));
            }

            std::cout << "[INFO] Sending real image " << copies << " times (" << (copies * orig_cols) << " total columns)...\n";

            auto t_start = std::chrono::high_resolution_clock::now();

            if (!bridge.sendImageStrip(images)) {
                std::cout << "Failed to send image strip.\n";
                break;
            }

            auto t_send_done = std::chrono::high_resolution_clock::now();

            constexpr FpgaOcrBridge::FsmState WAIT_ACK = FpgaOcrBridge::FsmState::WAIT_TX;
            if (!bridge.waitForFsm(WAIT_ACK, 1'000'000)) {
                std::cout << "Timed out waiting for WAIT_ACK state.\n";
                break;
            }

            auto t_fsm_done = std::chrono::high_resolution_clock::now();

            double send_time_ms = std::chrono::duration<double, std::milli>(t_send_done - t_start).count();
            double total_time_ms = std::chrono::duration<double, std::milli>(t_fsm_done - t_start).count();

            std::cout << "Image sent in " << send_time_ms << " ms\n";
            std::cout << "System reached WAIT_ACK in " << total_time_ms << " ms\n";

            bridge.printStatus();
            break;
        }



        case 0:
            std::cout << "Exiting...\n";
            return 0;

        default:
            std::cout << "Invalid option. Please choose 0–4.\n";
            break;
        }
    }

    return 0;
}
