// socket_server.hpp
#pragma once

#include <string>
#include <thread>
#include <atomic>
#include <functional>

class SocketServer {
public:
    using CommandHandler = std::function<std::string(const std::string&)>;

    SocketServer();
    ~SocketServer();

    bool start(const std::string& socket_path, CommandHandler handler);
    void stop();

private:
    void run();

    std::string socket_path_;
    CommandHandler command_handler_;
    std::thread server_thread_;
    std::atomic<bool> running_;
    int server_fd_ = -1;
};
