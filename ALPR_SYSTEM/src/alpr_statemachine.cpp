// alpr_statemachine.cpp
#include "alpr_statemachine.hpp"
#include <memory>
#include "utils.hpp"
#include <filesystem>
#include <bits/this_thread_sleep.h>

// Generate a default config file
static bool generateDefaultConfig(const std::string& path) {
    std::filesystem::create_directories("/etc/alpr_system");
    std::ofstream out(path);
    if (!out) return false;
    out << R"(
# General
mode=camera
input_path=./test_images
repeat_folder=false

# FPGA timeouts (raw uint8_t values)
fpga_watchdog_timeout=5
fpga_ocr_timeout=3

# Nanodet model cofig
model.param_path=./models/nanodet_128x128_V2_simplified.ncnn.param
model.bin_path=./models/nanodet_128x128_V2_simplified.ncnn.bin
model.num_threads=2
model.targer_size=125
model.prob_threshold = 0.6
model.nms_threshold = 0.65

# FPGA bridge config
fpga.unsafe_mode=false
fpga.timeout_cycles=1000
fpga.min_digits=7
fpga.max_digits=8
fpga.watchdog_pio=20
fpga.watchdog_ocr=200
fpga.ocr_break=false
fpga.ignore_invalid_cmd=false

# Debugging
debug.deep=false
debug.state_machine=true
debug.preprocess=true
debug.detection=false
debug.fpga=false
debug.transfer=false

# Logging
log_dir=./logs
log_rotation_hours=2
log_max_size_mb=2
log_save_interval_sec=30
log_max_entries=200

# Plate result logging
plate_dir=./plates
plate_rotation_hours=1
plate_max_size_mb=15
plate_save_interval_sec=60
plate_max_entries=3000

# Time sync
set_time_on_startup=true
)";
    return true;
}

std::string AlprStateMachine::stateToString(State state)
{
    switch (state) {
    case State::INIT:  return "INIT";
    case State::BEGIN: return "BEGIN";
    case State::ERROR: return "ERROR";
    case State::HALT:  return "HALT";
        // Add more states here as needed
    default:           return "UNKNOWN";
    }
}


AlprStateMachine::AlprStateMachine(const Config& cfg, bool service_mode, std::shared_ptr<Logger> logger)
    : config_(cfg), is_service_(service_mode), logger_(logger), current_state_(State::INIT) {
}

AlprStateMachine::~AlprStateMachine()
{
    std::lock_guard<std::mutex> lock(mutex_);
    cap_.release();
    lcd_.~LcdLiveDisplay();
}

bool AlprStateMachine::isRunning() {
    std::lock_guard<std::mutex> lock(mutex_);
    return running_;
}


void AlprStateMachine::requestStop() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::cout << "[FSM] Stop requested externally.\n";
    current_state_ = State::HALT;  // trigger graceful exit
}

std::string AlprStateMachine::getStatusSnapshot() {
    // Here, mutex_ must already be locked!

    std::lock_guard<std::mutex> lock(mutex_);
    std::string result;
    result += "state=" + stateToString(fsm_status_snapshot_);
    result += ", running=" + std::to_string(running_);
    return result;
}

bool AlprStateMachine::run() {
    running_ = true;
    std::cerr << "ALPR State Machine started" << "\n";

    while (running_) {

        std::lock_guard<std::mutex> lock(mutex_);
        if (!running_) break;
        fsm_status_snapshot_ = current_state_;
        auto now = std::chrono::steady_clock::now();
        auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_lcd_update_).count();
        if (lcd_ && elapsed_ms >= LCD_UPDATE_INTERVAL_MS) {
            lcd_.update(last_lp_, fps_, avg_lp_time_ms_, frame_lp_count_, total_lp_count_, error_count_, running_lcd_status_);
            last_lcd_update_ = now;
        }
        switch (current_state_) {
        case State::INIT:
            if (!handleInit()) {
                std::cerr << "Initialization failed. Halting." << "\n";
                
                return false;
            }
            break;

        case State::BEGIN:
            if (debug_state_machine_) {
                logger_->maybeFlushLog();
            }
            // Next processing logic will go here
            logger_->maybeFlushLog();
            break;

        case State::ERROR:
            logger_->logError("FSM entered ERROR state. Exiting run loop.");
            running_lcd_status_ = LcdLiveDisplay::LcdStatus::Error;
            break;

        case State::HALT:
            logger_->logMsg("FSM received HALT. Exiting run loop.");
            running_lcd_status_ = LcdLiveDisplay::LcdStatus::Offline;
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            if (lcd_)lcd_.update("--------", 0, 0, 0, 0, 0, LcdLiveDisplay::LcdStatus::Offline);
            fpga_bridge_->cmdReset();
            running_ = false;
            logger_->forceFlushLog();
            logger_->forceFlushPlate();
            return true;
        }

        // Regular log flush even if state doesn't change
        
    }

    return true;
}

bool AlprStateMachine::handleInit() {
    std::string configPath = "/etc/alpr_system/config.ini";

    // PHASE 1: Config load / creation
    if (!config_.loadFromFile(configPath)) {
        std::cerr << "[WARN] Config not found: " << configPath << "\n";

        if (is_service_) {
            std::cerr << "[INFO] Service mode: generating default config.\n";
            if (!generateDefaultConfig(configPath)) {
                std::cerr << "[ERROR] Failed to write config.\n";
                current_state_ = State::ERROR;
                return false;
            }
            std::cerr << "[INFO] Default config written. Please restart.\n";
            current_state_ = State::ERROR;
            return false;
        }
        else {
            std::cerr << "[USER MODE] Create default config? [Y/n]: ";
            std::string input;
            std::getline(std::cin, input);
            if (input.empty() || input == "y" || input == "Y") {
                if (!generateDefaultConfig(configPath)) {
                    std::cerr << "[ERROR] Failed to write config.\n";
                    current_state_ = State::ERROR;
                    return false;
                }
                std::cout << "[INFO] Config created at: " << configPath << "\n";
            }
            else {
                std::cerr << "[ABORTED] User cancelled.\n";
                current_state_ = State::ERROR;
                return false;
            }
        }
    }

    // PHASE 2: Config loaded — initialize logger
    plate_dir_ = config_.getString("plate_dir", "./plates");
    plate_rotation_hours_ = config_.getInt("plate_rotation_hours", 1);
    plate_max_size_mb_ = config_.getInt("plate_max_size_mb", 15);
    plate_save_interval_sec_ = config_.getInt("plate_save_interval_sec", 60);
    plate_max_entries_ = config_.getInt("plate_max_entries", 3000);

    log_dir_ = config_.getString("log_dir", "./logs");
    log_rotation_hours_ = config_.getInt("log_rotation_hours", 2);
    log_max_size_mb_ = config_.getInt("log_max_size_mb", 2);
    log_save_interval_sec_ = config_.getInt("log_save_interval_sec", 30);
    log_max_entries_ = config_.getInt("log_max_entries", 200);

    bool log_ready = logger_->initialize(
        plate_dir_, plate_rotation_hours_, plate_max_size_mb_,
        plate_save_interval_sec_, plate_max_entries_,
        log_dir_, log_rotation_hours_, log_max_size_mb_,
        log_save_interval_sec_, log_max_entries_,
        !is_service_  // interactive_mode
    );

    if (!log_ready) {
        std::cerr << "[ERROR] Logger failed to initialize.\n";
        current_state_ = State::ERROR;
        return false;
    }


    logger_->logMsg("Config loaded successfully.");
    unsafe_mode_ = config_.getBool("fpga.unsafe_mode", false);
    timeout_cycles_ = config_.getInt("fpga.timeout_cycles", 1000);
    min_digits_ = static_cast<uint8_t>(config_.getInt("fpga.min_digits", 7));
    max_digits_ = static_cast<uint8_t>(config_.getInt("fpga.max_digits", 8));
    ocr_break_ = config_.getBool("fpga.ocr_break", false);
    ignore_invalid_cmd_ = config_.getBool("fpga.ignore_invalid_cmd", false);
    watchdog_pio_ = config_.getInt("fpga.watchdot_pio", 20);
    watchdog_ocr_ = config_.getInt("fpga.watchdot_ocr", 200);
    logger_->logDebug("state", "Logger initialized.");

    if (debug_fpga_)
        logger_->logDebug("fpga", "FPGA Config: unsafe_mode=" + std::to_string(unsafe_mode_) +
        ", timeout_cycles=" + std::to_string(timeout_cycles_) +
        ", min_digits=" + std::to_string(min_digits_) +
        ", max_digits=" + std::to_string(max_digits_) +
        ", ocr_break=" + std::to_string(ocr_break_) +
        ", ignore_invalid_cmd=" + std::to_string(ignore_invalid_cmd_) +
        ", watchdot_pio=" + std::to_string(watchdog_pio_) +
        ", watchdot_ocr=" + std::to_string(watchdog_ocr_));

    if (debug_state_machine_)
        logger_->logDebug("state", "Plate Log Config: dir=" + plate_dir_ +
        ", rotation_hours=" + std::to_string(plate_rotation_hours_) +
        ", max_size_mb=" + std::to_string(plate_max_size_mb_) +
        ", save_interval_sec=" + std::to_string(plate_save_interval_sec_) +
        ", max_entries=" + std::to_string(plate_max_entries_));

    if (debug_state_machine_)
        logger_->logDebug("state", "Log Config: dir=" + log_dir_ +
        ", rotation_hours=" + std::to_string(log_rotation_hours_) +
        ", max_size_mb=" + std::to_string(log_max_size_mb_) +
        ", save_interval_sec=" + std::to_string(log_save_interval_sec_) +
        ", max_entries=" + std::to_string(log_max_entries_));

    model_param_path_ = config_.getString("model.param_path", "nanodet_128x128.param");
    if (!fileExists(model_param_path_)) {
        logger_->logError("Initialization failed. Model param file missing: " + model_param_path_);
        current_state_ = State::ERROR;
        return false;
    }

    model_bin_path_ = config_.getString("model.bin_path", "nanodet_128x128.bin");
    if (!fileExists(model_bin_path_)) {
        logger_->logError("Initialization failed. Model bin file missing: " + model_bin_path_);
        current_state_ = State::ERROR;
        return false;
    }

    model_num_threads_ = config_.getInt("model.num_threads", 2);
    model_target_size_ = config_.getInt("model.target_size", 128);
    model_prob_threshold_ = std::stof(config_.getString("model.prob_threshold", "0.6"));
    model_nms_threshold_ = std::stof(config_.getString("model.nms_threshold", "0.65"));

    run_mode_ = config_.getString("mode", "camera");
    if (debug_state_machine_)
        logger_->logDebug("state", "operation mode set to " + run_mode_);

    if (debug_state_machine_)
        logger_->logDebug("state", "NCNN Model Config: param=" + model_param_path_ +
        ", bin=" + model_bin_path_ +
        ", threads=" + std::to_string(model_num_threads_) +
        ", target_size=" + std::to_string(model_target_size_) +
        ", prob_thresh=" + std::to_string(model_prob_threshold_) +
        ", nms_thresh=" + std::to_string(model_nms_threshold_));


    detector_ = std::make_unique<NanoDet>(
        model_param_path_, model_bin_path_,
        model_num_threads_, model_target_size_,
        model_prob_threshold_, model_nms_threshold_);
    if (!detector_) { 
        logger_->logError("Fail to load NCNN model!");
        current_state_ = State::ERROR;
        return false;
    }
    logger_->logMsg("NCNN model as been loaded");
    
    if (run_mode_ == "camera")
    {
        cap_.open(0);;
        if (!cap_.isOpened()) {

            logger_->logError("Error: Unable to open the camera.");
            current_state_ = State::ERROR;
            return false;
        }
        if (debug_state_machine_)
            logger_->logDebug("state","Camera open start warmup");
        int warmup_frames = 5;
        for (int i = 0; i < warmup_frames; ++i) {
            cv::Mat temp_frame;
            cap_ >> temp_frame;
            if (temp_frame.empty()) {
                if (debug_state_machine_)
                    logger_->logDebug("state", "Warning: Blank frame grabbed during warm-up.");
            }
        }

    }
    if (!lcd_.init()) {
        logger_->logError("Error: LCD failed to initialize.");
        current_state_ = State::ERROR;
        return false;
    }
    if (debug_state_machine_)
        logger_->logDebug("state", "LCD initialize.");

    fpga_bridge_ = std::make_unique<FpgaOcrBridge>(timeout_cycles_, debug_fpga_, unsafe_mode_);
    if (!fpga_bridge_->cmdReset()) {
        logger_->logError("Fail to init fpga!");
        current_state_ = State::ERROR;
        return false;
    }
    if(!fpga_bridge_->cmdInit(min_digits_,max_digits_,watchdog_pio_,watchdog_ocr_,ocr_break_,ignore_invalid_cmd_)) {
        logger_->logError("Fail to init fpga!");
        current_state_ = State::ERROR;
        return false;
    }
    if (debug_state_machine_)
        logger_->logDebug("state", "FPGA has been reset and init.");

    running_lcd_status_ = LcdLiveDisplay::LcdStatus::Running;
    current_state_ = State::BEGIN;
    return true;
}



