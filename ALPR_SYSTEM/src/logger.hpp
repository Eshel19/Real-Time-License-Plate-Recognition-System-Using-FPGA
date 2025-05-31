// logger.hpp
#pragma once

#include <string>
#include <vector>
#include <fstream>
#include <chrono>
#include <mutex>


class Logger {
public:
    Logger();

    bool initialize(
        const std::string& plate_dir, int plate_rotation_hours, int plate_max_size_mb,
        int plate_flush_interval_sec, int plate_max_entries,
        const std::string& log_dir, int log_rotation_hours, int log_max_size_mb,
        int log_flush_interval_sec, int log_max_entries,
        bool interactive_mode
    );
    ~Logger();
    void logMsg(const std::string& msg);
    void logDebug(const std::string& tag, const std::string& msg);
    void logError(const std::string& msg);
    void maybeFlushPlate();
    void maybeFlushLog();
    void forceFlushPlate();
    void forceFlushLog();
    void addPlateLog(const std::string& log_line);

private:

    void openNewPlateFile();
    void openNewLogFile();
    void rotatePlateIfNeeded();
    void rotateLogIfNeeded();



    std::vector<std::string> log_buffer_;

    std::string makeTimestampedFilename();
    size_t currentFileSizeMB(const std::string& path);

    std::string timestamp();
    std::mutex mutex_;

    // Directories and file paths
    std::string plate_dir_;
    std::string log_dir_;
    std::string current_plate_filename_;
    std::string current_log_filename_;

    // File streams
    std::ofstream log_outfile_;       
    std::ofstream plate_outfile_;     

    // Flush timing
    std::chrono::steady_clock::time_point last_plate_flush_time_;
    std::chrono::steady_clock::time_point last_log_flush_time_;
    std::chrono::system_clock::time_point plate_file_start_time_;
    std::chrono::system_clock::time_point log_file_start_time_;

    // Rotation & flush config
    int plate_rotation_hours_ = 1;
    int plate_max_size_mb_ = 15;
    int plate_flush_interval_sec_ = 60;
    int plate_max_entries_ = 3000;

    int log_rotation_hours_ = 2;
    int log_max_size_mb_ = 2;
    int log_flush_interval_sec_ = 30;
    int log_max_entries_ = 200;

    bool interactive_mode_ = false;
    
    std::vector<std::string> plate_buffer_;
};
