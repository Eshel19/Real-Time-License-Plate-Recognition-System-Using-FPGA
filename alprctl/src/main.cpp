#include "ipc_shared.hpp"
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <string>
#include <cstdlib>
#include <chrono>
#include <thread>

bool is_daemon_running() {
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0)
        return false;
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, ALPR_SOCKET_PATH, sizeof(addr.sun_path) - 1);
    bool connected = connect(sock, (sockaddr*)&addr, sizeof(addr)) == 0;
    close(sock);
    return connected;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: alprctl <command>\n";
        return 1;
    }
    std::string command = argv[1];

    // Special handling for "start"
    if (command == "start") {
        if (is_daemon_running()) {
            std::cout << "ALPR service is already running.\n";
            return 0;
        }
        std::cout << "Starting ALPR service...\n";
        int ret = std::system("systemctl start alpr_system.service");
        if (ret != 0) {
            std::cerr << "[ERROR] Failed to start alpr_system.service\n";
            return 1;
        }
        // Optionally: wait until it's up (timeout)
        constexpr int max_tries = 50;
        int tries = 0;
        for (; tries < max_tries; ++tries) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            if (is_daemon_running()) {
                std::cout << "ALPR service started.\n";
                return 0;
            }
        }
        std::cerr << "[ERROR] Timeout waiting for ALPR service to start.\n";
        return 1;
    }

    // Normal controller logic for other commands
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        std::cerr << "[ERROR] Failed to create socket\n";
        return 1;
    }
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, ALPR_SOCKET_PATH, sizeof(addr.sun_path) - 1);
    if (connect(sock, (sockaddr*)&addr, sizeof(addr)) < 0) {
        std::cerr << "[ERROR] Failed to connect to ALPR daemon\n";
        close(sock);
        return 1;
    }
    if (write(sock, command.c_str(), command.size()) < 0) {
        std::cerr << "[ERROR] Failed to send command\n";
        close(sock);
        return 1;
    }
    char buffer[1024] = { 0 };
    ssize_t n = read(sock, buffer, sizeof(buffer) - 1);
    if (n > 0) {
        std::cout << buffer << std::endl;
    }
    else {
        std::cerr << "[ERROR] Failed to read response\n";
    }
    close(sock);
    return 0;
}
