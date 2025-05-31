#include "ipc_shared.hpp"
#include "alpr_statemachine.hpp"
#include "config.hpp"
#include "logger.hpp"
#include <iostream>
#include <fstream>
#include <memory>
#include <unistd.h>
#include <csignal>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "socket_server.hpp"
#include <filesystem>
#include <unordered_map>
#include <functional>
#include <string>


const std::string PID_FILE = "/run/alpr_system.pid";

bool isAlreadyRunning() {
    std::ifstream pid_in(PID_FILE);
    if (pid_in) {
        pid_t pid;
        pid_in >> pid;
        if (kill(pid, 0) == 0) {
            std::cerr << "[ERROR] ALPR service already running (PID: " << pid << ")\n";
            return true;
        }
    }
    return false;
}

bool writePidFile() {
    std::ofstream pid_out(PID_FILE);
    if (!pid_out) return false;
    pid_out << getpid();
    return true;
}

void removePidFile() {
    unlink(PID_FILE.c_str());
}

void handleSignal(int sig) {
    std::cerr << "\n[SIGNAL] Received signal " << sig << ", shutting down.\n";
    removePidFile();
    exit(0);
}

using CommandHandlerMap = std::unordered_map<std::string, std::function<std::string()>>;

CommandHandlerMap make_command_map(
    std::shared_ptr<AlprStateMachine> fsm,
    std::shared_ptr<Logger> logger
) {
    CommandHandlerMap command_map{
        {"stop", [fsm, logger]() {
            logger->logMsg("[CMD] Stop received.");
            std::thread([fsm, logger]() {
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                fsm->requestStop();
                std::this_thread::sleep_for(std::chrono::milliseconds(100));
                logger->~Logger();
                fsm->~AlprStateMachine();
                removePidFile();
                exit(0);
            }).detach();
            return "[OK] Stop";
        }},
        {"status", [fsm, logger]() {
            logger->logMsg("[CMD] status.");
            
            return fsm->getStatusSnapshot();
        }},
        // ...add more commands...
    };
    return command_map;
}


int main() {
    std::filesystem::create_directories("/run/alpr_system");
    signal(SIGINT, handleSignal);
    signal(SIGTERM, handleSignal);

    if (isAlreadyRunning()) return 1;
    if (!writePidFile()) return 1;

    bool is_service = !isatty(STDIN_FILENO); 
    Config config;
    auto logger = std::make_shared<Logger>();
    auto fsm = std::make_shared<AlprStateMachine>(config, is_service, logger);
    auto socket_server = std::make_shared<SocketServer>();
    auto command_map = make_command_map(fsm, logger);
    if (!socket_server->start(ALPR_SOCKET_PATH, [command_map](const std::string& cmd) mutable {
        auto it = command_map.find(cmd);
        if (it != command_map.end()) {
            return it->second();
        }
        else {
            return std::string("[ERROR] Unknown command");
        }
        })) {
        std::cerr << "[ERROR] Failed to start socket server.\n";
        removePidFile();
        return 1;
    }
    else {
        std::cout << "[SOCKET] Listening on: " << ALPR_SOCKET_PATH << "\n";
    }
    if (!fsm->run()) {
        std::cerr << "[FSM] Exited with error\n";
        removePidFile();
        return 1;
    }
    removePidFile();
    return 0;
}


