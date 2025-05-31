// Logger.cpp
#include "logger.hpp"
#include <iostream>
#include <iomanip>
#include <ctime>
#include <filesystem>

Logger::Logger() {}

bool Logger::initialize(
    const std::string& plate_dir, int plate_rotation_hours, int plate_max_size_mb,
    int plate_flush_interval_sec, int plate_max_entries,
    const std::string& log_dir, int log_rotation_hours, int log_max_size_mb,
    int log_flush_interval_sec, int log_max_entries,
    bool interactive_mode)
{
    plate_dir_ = plate_dir;
    plate_rotation_hours_ = plate_rotation_hours;
    plate_max_size_mb_ = plate_max_size_mb;
    plate_flush_interval_sec_ = plate_flush_interval_sec;
    plate_max_entries_ = plate_max_entries;

    log_dir_ = log_dir;
    log_rotation_hours_ = log_rotation_hours;
    log_max_size_mb_ = log_max_size_mb;
    log_flush_interval_sec_ = log_flush_interval_sec;
    log_max_entries_ = log_max_entries;

    interactive_mode_ = interactive_mode;

    std::filesystem::create_directories(plate_dir_);
    std::filesystem::create_directories(log_dir_);

    openNewPlateFile();
    openNewLogFile();

    return plate_outfile_.is_open() && log_outfile_.is_open();
}
Logger::~Logger() {
    // Make sure any buffered data is flushed
    forceFlushPlate();
    forceFlushLog();

    // Close the file streams if they're open
    if (plate_outfile_.is_open()) {
        plate_outfile_.close();
    }
    if (log_outfile_.is_open()) {
        log_outfile_.close();
    }
}
void Logger::addPlateLog(const std::string& log_line) {
    plate_buffer_.push_back(log_line);
    maybeFlushPlate();
}

void Logger::logMsg(const std::string& msg) {
    std::string line = timestamp() + " [INFO] " + msg;
    if (interactive_mode_) std::cout << line << std::endl;
    log_buffer_.push_back(line);
    maybeFlushLog();
}

void Logger::logDebug(const std::string& tag, const std::string& msg) {
    std::string line = timestamp() + " [DEBUG][" + tag + "] " + msg;
    if (interactive_mode_) std::cout << line << std::endl;
    log_buffer_.push_back(line);
    maybeFlushLog();
}

void Logger::logError(const std::string& msg) {
    std::string line = timestamp() + " [ERROR] " + msg;
    if (interactive_mode_) std::cerr << line << std::endl;
    log_buffer_.push_back(line);
    maybeFlushLog();
}

void Logger::maybeFlushPlate() {
    auto now = std::chrono::steady_clock::now();
    bool time_exceeded = std::chrono::duration_cast<std::chrono::seconds>(now - last_plate_flush_time_).count() >= plate_flush_interval_sec_;
    bool buffer_full = plate_buffer_.size() >= static_cast<size_t>(plate_max_entries_);

    if (time_exceeded || buffer_full) forceFlushPlate();
}

void Logger::maybeFlushLog() {
    auto now = std::chrono::steady_clock::now();
    bool time_exceeded = std::chrono::duration_cast<std::chrono::seconds>(now - last_log_flush_time_).count() >= log_flush_interval_sec_;
    bool buffer_full = log_buffer_.size() >= static_cast<size_t>(log_max_entries_);

    if (time_exceeded || buffer_full) forceFlushLog();
}

void Logger::forceFlushPlate() {
    if (!plate_outfile_.is_open()) return;
    for (const auto& line : plate_buffer_) {
        plate_outfile_ << line << "\n";
    }
    plate_outfile_.flush();
    plate_buffer_.clear();
    last_plate_flush_time_ = std::chrono::steady_clock::now();
    rotatePlateIfNeeded();
}

void Logger::forceFlushLog() {
    if (!log_outfile_.is_open()) return;
    for (const auto& line : log_buffer_) {
        log_outfile_ << line << "\n";
    }
    log_outfile_.flush();
    log_buffer_.clear();
    last_log_flush_time_ = std::chrono::steady_clock::now();
    rotateLogIfNeeded();
}

void Logger::openNewPlateFile() {
    current_plate_filename_ = plate_dir_ + "/plates_" + makeTimestampedFilename() + ".csv";
    plate_outfile_.open(current_plate_filename_, std::ios::out | std::ios::app);
    last_plate_flush_time_ = std::chrono::steady_clock::now();
    plate_file_start_time_ = std::chrono::system_clock::now();
}

void Logger::openNewLogFile() {
    current_log_filename_ = log_dir_ + "/log_" + makeTimestampedFilename() + ".log";
    log_outfile_.open(current_log_filename_, std::ios::out | std::ios::app);
    last_log_flush_time_ = std::chrono::steady_clock::now();
    log_file_start_time_ = std::chrono::system_clock::now();
}

void Logger::rotatePlateIfNeeded() {
    auto now = std::chrono::system_clock::now();
    auto age_hours = std::chrono::duration_cast<std::chrono::hours>(now - plate_file_start_time_).count();
    if (age_hours >= plate_rotation_hours_ || currentFileSizeMB(current_plate_filename_) >= static_cast<size_t>(plate_max_size_mb_)) {
        plate_outfile_.close();
        openNewPlateFile();
    }
}

void Logger::rotateLogIfNeeded() {
    auto now = std::chrono::system_clock::now();
    auto age_hours = std::chrono::duration_cast<std::chrono::hours>(now - log_file_start_time_).count();
    if (age_hours >= log_rotation_hours_ || currentFileSizeMB(current_log_filename_) >= static_cast<size_t>(log_max_size_mb_)) {
        log_outfile_.close();
        openNewLogFile();
    }
}

std::string Logger::makeTimestampedFilename() {
    auto now = std::chrono::system_clock::now();
    std::time_t t = std::chrono::system_clock::to_time_t(now);
    std::tm* tm_info = std::localtime(&t);
    std::ostringstream oss;
    oss << std::put_time(tm_info, "%Y-%m-%d_%H");
    return oss.str();
}

size_t Logger::currentFileSizeMB(const std::string& filename) {
    if (!std::filesystem::exists(filename)) return 0;
    auto size = std::filesystem::file_size(filename);
    return size / (1024 * 1024);
}

std::string Logger::timestamp() {
    auto now = std::chrono::system_clock::now();
    std::time_t t = std::chrono::system_clock::to_time_t(now);
    std::tm* tm_info = std::localtime(&t);
    std::ostringstream oss;
    oss << std::put_time(tm_info, "%Y-%m-%d %H:%M:%S");
    return oss.str();
}
