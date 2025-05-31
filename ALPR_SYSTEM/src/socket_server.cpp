// socket_server.cpp
#include "socket_server.hpp"
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <filesystem>

SocketServer::SocketServer() : running_(false) {}

SocketServer::~SocketServer() {
    stop();
}

bool SocketServer::start(const std::string& socket_path, CommandHandler handler) {
    if (running_) return false;

    socket_path_ = socket_path;
    command_handler_ = handler;
    running_ = true;

    std::filesystem::create_directories(std::filesystem::path(socket_path_).parent_path());
    ::unlink(socket_path_.c_str());

    server_fd_ = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_fd_ < 0) {
        std::cerr << "[SOCKET] Failed to create socket." << std::endl;
        return false;
    }

    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, socket_path_.c_str(), sizeof(addr.sun_path) - 1);
    std::cout << "[DEBUG] Attempting bind to: " << socket_path_ << "\n";
    std::cout << "[DEBUG] Length = " << socket_path_.length() << "\n";
    std::cout << "[DEBUG] sun_path = " << addr.sun_path << "\n";

    if (::bind(server_fd_, (sockaddr*)&addr, sizeof(addr)) < 0) {
        std::cerr << "[SOCKET] Failed to bind socket." << std::endl;
        ::close(server_fd_);
        return false;
    }

    if (::listen(server_fd_, 5) < 0) {
        std::cerr << "[SOCKET] Failed to listen on socket." << std::endl;
        ::close(server_fd_);
        return false;
    }

    server_thread_ = std::thread(&SocketServer::run, this);
    std::cout << "[SOCKET] Server listening on: " << socket_path_ << "\n";
    return true;
}

void SocketServer::stop() {
    std::cout << "[SOCKET] stop() called. Socket will be closed and unlinked.\n";

    running_ = false;
    if (server_fd_ >= 0) {
        ::close(server_fd_);
        server_fd_ = -1;
        ::unlink(socket_path_.c_str());
    }
    if (server_thread_.joinable()) {
        server_thread_.join();
    }
}

void SocketServer::run() {
    while (running_) {
        int client_fd = ::accept(server_fd_, nullptr, nullptr);
        if (client_fd < 0) continue;

        char buffer[1024] = { 0 };
        ssize_t len = ::read(client_fd, buffer, sizeof(buffer) - 1);
        if (len > 0) {
            std::string command(buffer, len);
            std::string response = command_handler_(command);
            ::write(client_fd, response.c_str(), response.size());
        }

        ::close(client_fd);
    }
}
