#include "ipc_shared.hpp"
#include <sys/socket.h>     // for socket(), connect()
#include <sys/un.h>         // for sockaddr_un
#include <unistd.h>         // for read(), write(), close()
#include <cstring>          // for strncpy(), memset()
#include <iostream>         // for std::cerr, std::cout
#include <string>


int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: alprctl <command>\n";
        return 1;
    }

    std::string command = argv[1];

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

    // Send command
    if (write(sock, command.c_str(), command.size()) < 0) {
        std::cerr << "[ERROR] Failed to send command\n";
        close(sock);
        return 1;
    }

    // Receive response
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
