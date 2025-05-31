#include <sys/stat.h>
#include <string>
#include <iostream>
#include <iomanip>
#include <sys/time.h>
#include <unistd.h>


inline bool fileExists(const std::string& path) {
    struct stat buffer;
    return (stat(path.c_str(), &buffer) == 0);
}


inline bool isLikelyServiceMode() {
    // If running as root and has no TTY, assume service mode
    return (geteuid() == 0) && (isatty(fileno(stdin)) == 0);
}


inline bool promptAndSetSystemTime() {
    std::string input;
    std::cout << "Enter current date and time (YYYY-MM-DD HH:MM:SS): ";
    std::getline(std::cin, input);

    std::tm t = {};
    std::istringstream ss(input);
    ss >> std::get_time(&t, "%Y-%m-%d %H:%M:%S");
    if (ss.fail()) {
        std::cerr << "[ERROR] Invalid time format.\n";
        return false;
    }

    time_t new_time = mktime(&t);
    if (new_time == -1) {
        std::cerr << "[ERROR] Failed to convert time.\n";
        return false;
    }

    timeval tv = { .tv_sec = new_time, .tv_usec = 0 };
    if (settimeofday(&tv, nullptr) != 0) {
        perror("settimeofday");
        return false;
    }

    std::cout << "[OK] System time updated.\n";
    return true;
}