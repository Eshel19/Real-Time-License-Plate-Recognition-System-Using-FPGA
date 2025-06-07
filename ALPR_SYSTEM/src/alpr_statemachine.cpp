// alpr_statemachine.cpp
#include "alpr_statemachine.hpp"
#include <memory>
#include "utils.hpp"
#include <filesystem>
#include <bits/this_thread_sleep.h>

// Generate a default config file
bool AlprStateMachine::generateDefaultConfig(const std::string& path) {
    std::filesystem::create_directories(CONFIG_FOLDER_PATH);
    std::ofstream out(path);
    if (!out) return false;
    out << R"(
# General
mode=camera
input_path=./test_images
lcd=true
demo_mode=false
max_persists_empty_frames=10
max_fpga_persists_states=5

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
fpga.ocr_break=false
fpga.ignore_invalid_cmd=false
# FPGA timeouts (raw uint8_t values) 
fpga.watchdog_pio=20
fpga.watchdog_ocr=200

# Debugging
#WARRING DEEP  DEUBING WILL NOT JUST SAVE LOG IT WILL PRINT LOGS FROM ALL THE SUB APIS
debug.deep=false
debug.state_machine=false
debug.preprocess=false
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

    return config_.loadFromFile(path);
}

std::string AlprStateMachine::stateToString(State state)
{
    switch (state) {
    case State::INIT:           return "INIT";
    case State::FRAME_CUPTURE:  return "FRAME_CUPTURE";
    case State::DETECTION:      return "DETECTION";
    case State::SEGMENATION:    return "SEGMENATION";
    case State::CHECK_FPGA:     return "CHECK_FPGA";
    case State::SEND_IMAGE:     return "SEND_IMAGE";
    case State::SEND_ACK:       return "SEND_ACK";
    case State::POSTPROCESS:    return "POSTPROCESS";
    case State::RECEIVE_RESULT: return "RECEIVE_RESULT";
    case State::RESET_FPGA:     return "RESET_FPGA";
    case State::SPLIT_BANKS:    return "SPLIT_BANKS";
    case State::MARGE_BANKS:    return "MARGE_BANKS";
    case State::RESEND_IMAGE:   return "RESEND_IMAGE";
    case State::HALT:           return "HALT";
    case State::ERROR:          return "ERROR";
    default:                    return "UNKNOWN";
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

//Socket functions request
bool AlprStateMachine::isRunning() {
    std::lock_guard<std::mutex> lock(mutex_);
    return running_;
}

void AlprStateMachine::requestStop() {
    std::lock_guard<std::mutex> lock(mutex_);
    logger_->logMsg("[CMD] Stop received.");
    request_stop_ = true;
    current_state_ = State::HALT;  // trigger graceful exit
}

void AlprStateMachine::requestRestart() {
    std::lock_guard<std::mutex> lock(mutex_);
    fsm_restart_requested_ = true;
    logger_->logMsg("[CMD] Restart request");
}

std::string AlprStateMachine::getStatusSnapshot() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::string result;
    result += "FSM state= " + stateToString(fsm_status_snapshot_);
    std::string status_str = "";
    switch (running_lcd_status_) {
    case LcdStatus::Running:  status_str = "Running"; break;
    case LcdStatus::Paused:   status_str = "Paused";  break;
    case LcdStatus::Error:    status_str = "Error";   break;
    case LcdStatus::Offline:  status_str = "Offline"; break;
    }
    if (running_lcd_status_ == LcdStatus::Offline) {
        result += " the system is Offline";
    }
    else {
        int hh = static_cast<int>(status_duration_seconds_ / 3600);
        int mm = static_cast<int>((status_duration_seconds_ % 3600) / 60);
        int ss = static_cast<int>(status_duration_seconds_ % 60);

        std::ostringstream oss;
        oss << " The system is " << status_str << " for "
            << std::setfill('0') << std::setw(2) << hh << ":"
            << std::setfill('0') << std::setw(2) << mm << ":"
            << std::setfill('0') << std::setw(2) << ss;

        result += oss.str();
    }
    result+="\nAverage FPS: "+ std::to_string(fps_) + " Error counts: " + std::to_string(error_count_)+" Total detected LP: " + std::to_string(total_lp_count_) +" Last LP detected: " + last_lp_;
    logger_->logMsg("[CMD] status: "+ result);
    return result;
}

void AlprStateMachine::resetStateMachine() {
    
    current_state_ = State::INIT;
    if (cap_.isOpened()) cap_.release();
    detector_.reset();
    segmenter_.reset();
    fpga_bridge_.reset();
    current_frame_.release();
    object_clips_.clear();
    presend_images_.clear();
    sended_images_.clear();
    results_.clear();
    last_lp_list_.clear();
    folder_image_list_.clear();
    fpga_results_.clear();
    empty_frame_ = 0;
    folder_image_idx_ = 0;
    status_duration_seconds_ = 0;
    error_count_ = 0;
    fps_ = 0;
    last_lp_ = "--------";
    running_lcd_status_ = LcdStatus::Paused;
    logger_->logMsg("System parameter as been cleard");
}

//FSM MAIN operation function
bool AlprStateMachine::run() {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        running_ = true;
        std::cerr << "ALPR State Machine started" << "\n";
        last_status_lcd_ = LcdStatus::Offline;
    }

    while (running_) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!running_) break;
        if (fsm_restart_requested_) resetStateMachine(); 

        updateSystemStatus();
        if (request_stop_) current_state_ = State::HALT;
        switch (current_state_) {
        case State::INIT:
            if (!handleInit()) {
                std::cerr << "Initialization failed. Halting." << "\n";
                return false;
            }
            break;

        case State::FRAME_CUPTURE:
            handleFrameCapture();
            break;

        case State::DETECTION:
            handleDetection();
            break;

        case State::SEGMENATION:
            handleSegmenation();
            break;

        case State::CHECK_FPGA:
            handleCheckFpga();
            break;

        case State::SEND_IMAGE:
            handleSendImage();
            break;

        case State::SEND_ACK:
            handleSendAck();
            break;

        case State::POSTPROCESS:
            handlePostprocess();
            break;

        case State::RECEIVE_RESULT:
            handleReceiveResult();
            break;

        case State::RESET_FPGA:
            handleResetFpga();
            break;

        case State::SPLIT_BANKS:
            handleSplitBanks();
            break;

        case State::MARGE_BANKS:
            handleMargeBanks();
            break;

        case State::ERROR:
            handleError();
            break;

        case State::HALT:
            handleHalt();
        }

        // Flush logs, etc., if needed here
    }
    return true;
}

//
/// FSM handlers fucntion:
//
// 

// INIT: 
bool AlprStateMachine::handleInit() {
    std::string configPath = CONFIG_FILE_PATH;
    /*
    Initializes hardware (camera, buffers, FPGA interfaces)

    Allocates memory

    Loads configs, opens files

    Starts threads or timers

    Sets up I/O pins, PIOs, etc.
    */


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

    if(!logger_->isInitialized())
    {
        logger_->initialize(
            plate_dir_, plate_rotation_hours_, plate_max_size_mb_,
            plate_save_interval_sec_, plate_max_entries_,
            log_dir_, log_rotation_hours_, log_max_size_mb_,
            log_save_interval_sec_, log_max_entries_,
            !is_service_  // interactive_mode
        );
    }

    if (!logger_->isInitialized()) {
        std::cerr << "[ERROR] Logger failed to initialize.\n";
        current_state_ = State::ERROR;
        return false;
    }


    logger_->logMsg("Config loaded successfully.");

    lcd_en_= config_.getBool("lcd", false);
    debug_deep_ = config_.getBool("debug.deep", false);
    debug_detection_ = config_.getBool("debug.detection", false);
    debug_preprocess_ = config_.getBool("debug.preprocess", false);
    debug_fpga_ = config_.getBool("debug.fpga", false);
    debug_transfer_ = config_.getBool("debug.transfer", false);
    max_fpga_persists_states_ = config_.getInt("max_fpga_persists_states", 5);
    debug_state_machine_ = config_.getBool("debug.state_machine", false);
    max_persists_empty_frames_= config_.getInt("max_persists_empty_frames", 10);
    demo_mode_= config_.getBool("demo_mode", false);

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
    input_path_ = config_.getString("input_path", "./test_images");
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
    if (debug_state_machine_)
        logger_->logDebug("state","NCNN model as been loaded Starting warmup");
    int warmup_iterations = 5; // Number of warm-up iterations
    cv::Mat warmup_frame = cv::Mat::zeros(128, 128, CV_8UC3); // Dummy frame for warm-up
    for (int i = 0; i < warmup_iterations; ++i) {
        std::vector<Object> warmup_objects;
        detector_->detect(warmup_frame, warmup_objects);
    }
    if(debug_state_machine_)
        logger_->logDebug("state","NCNN Detection warm-up runs complete");
    
    segmenter_ = std::make_unique<ImageSegmenter>(
        1.2,          // gamma
        21,           // blockSize
        3,            // C
        debug_deep_,        // debug_time
        debug_deep_       // debug_parts
    );
    if (debug_state_machine_)
        logger_->logDebug("state", "Segmenter class as been initialize");

    run_mode_ = demo_mode_ ? "camera" : run_mode_;
    //Set for folder mode
    if (run_mode_ == "folder"||demo_mode_) {
        
        folder_image_list_.clear();
        for (const auto& entry : fs::directory_iterator(input_path_)) {
            if (entry.is_regular_file()) {
                folder_image_list_.push_back(entry.path().string());
            }
        }
        std::sort(folder_image_list_.begin(), folder_image_list_.end()); // Optional: predictable order
        folder_image_idx_ = 0;

        if (folder_image_list_.empty()) {
            logger_->logError("No images found in folder: " + input_path_);
            current_state_ = State::ERROR;
            return false;
        }
        logger_->logMsg("Folder mode enabled. Found " + std::to_string(folder_image_list_.size()) + " images.");
    }


    //Set for camera mode
    if (run_mode_ == "camera"||demo_mode_)
    {
        cap_.open(0, cv::CAP_V4L2);
        if (!cap_.isOpened()) {

            logger_->logError("Error: Unable to open the camera.");
            current_state_ = State::ERROR;
            return false;
        }
        if (debug_state_machine_)
            logger_->logDebug("state","Camera open start warmup");
        int warmup_frames = 5;
        int empty_frames_count = 0;
        for (int i = 0; i < warmup_frames; ++i) {
            cv::Mat temp_frame;
            cap_ >> temp_frame;
            if (temp_frame.empty()) {
                if (debug_state_machine_)
                    logger_->logDebug("state", "Warning: Blank frame grabbed during warm-up.");
                empty_frames_count++;
            }
        }
        if (empty_frames_count == 5)
        {
            if (demo_mode_)
            {
                logger_->logMsg("Demo mode is on ignoring fail camera init");
                run_mode_ = "folder";
            }
            else
            {
                logger_->logError("Error: Unable to open the camera.");
                current_state_ = State::ERROR;
                return false;
            }
            
        }
    }
    
    if(!lcd_)
    {
        if (lcd_en_) {
            if (!lcd_.init()) {
                logger_->logError("Error: LCD failed to initialize.");
                current_state_ = State::ERROR;
                return false;
            }
            if (debug_state_machine_)
                logger_->logDebug("state", "LCD initialize.");
        }
    }
    
    fpga_bridge_ = std::make_unique<FpgaOcrBridge>(timeout_cycles_, debug_deep_, unsafe_mode_);
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

    if (fsm_restart_requested_)
    {
        fsm_restart_requested_ = false;
        logger_->logMsg("System has beem fully reset and re-init");
    }else 
        logger_->logMsg("System initialize has been complete");

    running_lcd_status_ = LcdLiveDisplay::LcdStatus::Running;
    current_state_ = State::FRAME_CUPTURE;

    return true;
}

// FRAME_CAPTURE: grab next frame
void AlprStateMachine::handleFrameCapture() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter FRAME_CUPTURE State.");

    auto now = std::chrono::steady_clock::now();
    if (fps_window_start_time_.time_since_epoch().count() == 0)
        fps_window_start_time_ = now;

    fps_window_frame_count_++;

    float elapsed_window_sec = std::chrono::duration<float>(now - fps_window_start_time_).count();

    if (elapsed_window_sec >= FPS_WINDOW_SEC) {
        fps_ = static_cast<float>(fps_window_frame_count_) / elapsed_window_sec;
        fps_window_start_time_ = now;
        fps_window_frame_count_ = 0;
    }
    last_frame_time_ = now;
    if (run_mode_ == "folder") {
        if (folder_image_list_.empty()) {
            logger_->logError("No images in folder list!");
            current_state_ = State::ERROR;
            return;
        }

        const std::string& img_path = folder_image_list_[folder_image_idx_];
        current_frame_ = cv::imread(img_path, cv::IMREAD_COLOR);
        if (current_frame_.empty()) {
            logger_->logError("Failed to read image: " + img_path);
            // Advance index and try next image (or handle as error/fatal)
            folder_image_idx_ = (folder_image_idx_ + 1) % folder_image_list_.size();
            current_state_ = State::ERROR;
            return;
        }
        if (debug_preprocess_)
            logger_->logDebug("preprocess", "Loaded image: " + img_path);

        // Advance index for next call (FIFO/circular)
        folder_image_idx_ = (folder_image_idx_ + 1) % folder_image_list_.size();
    }
    
    if(run_mode_ == "camera")
    {
        cap_ >> current_frame_;
        if (current_frame_.empty()) {
            error_count_++;
            logger_->logError("Frame capture failed (camera may be disconnected)");

            // Try to recover camera immediately
            cap_.release();
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            bool reopened = cap_.open(0, cv::CAP_V4L2); // Use your actual camera index/path

            if (!reopened || !cap_.isOpened()) {
                empty_frame_++; // Only increment if recovery also failed

                logger_->logError("Camera recovery failed (attempt " + std::to_string(empty_frame_) + ")");
                
                if (empty_frame_ >= max_persists_empty_frames_) { // e.g. 10
                    if (demo_mode_)
                    {
                        logger_->logMsg("Demo mode is on ignoring fail camera init");
                        run_mode_ = "folder";
                    }
                    else
                    {
                        logger_->logError("Critical error: camera failing to recover after multiple attempts!");
                        current_state_ = State::ERROR;
                        return;
                    }
                }
                current_state_ = State::FRAME_CUPTURE;
                return;
            }
        }
        else {
            if (empty_frame_ > 0) {
                logger_->logMsg("Camera recovered automatically after " + std::to_string(empty_frame_) + " failure(s).");
                empty_frame_ = 0;
            }
            // If empty_frame_ is already 0, do nothing
        }
        if (debug_preprocess_)
            logger_->logDebug("preprocess", "Capture Frame");
    }
    
    current_state_ = State::DETECTION;
}

// DETECTION: run LP detection on the frame
void AlprStateMachine::handleDetection() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter Detection State.");

    // Run detector_ on current frame, get LP bboxes.
    std::vector<Object> objects;
    detector_->detect(current_frame_, objects);

    if (objects.empty()) {
        if (debug_preprocess_)
            logger_->logDebug("preprocess", "No LP been detected in the frame");
        if(fpga_job_pending_) 
            current_state_ = State::CHECK_FPGA;
        else
            current_state_ = State::FRAME_CUPTURE;  // Should probably go back to capture, not stay in DETECTION!
        return;
    }

    if (debug_preprocess_)
        logger_->logDebug("preprocess", "Detected " + std::to_string(objects.size()) + " LP(s) in the frame");

    detector_->extract_object_clips_clone(current_frame_, objects, object_clips_);
    if (object_clips_.empty())
    {
        logger_->logError("Object detected but fail to be extect from image");
    }
    current_state_ = State::SEGMENATION;
}

// SEGMENATION: segment detected LPs
void AlprStateMachine::handleSegmenation() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter Segmenation State.");
    // For each bbox, run segmenter_, add result to prep bank.
    for (size_t i = 0; i < object_clips_.size(); ++i) {
        // Resize the object image if its height is greater than 100 pixels
        cv::Mat obj_image = object_clips_[i];
        int original_height = obj_image.rows;

        if (original_height > 100) {
            double scale_factor = 100.0 / original_height;
            int new_width = static_cast<int>(obj_image.cols * scale_factor);
            int new_height = 100;

            // Ensure new dimensions are valid
            if (new_width > 0 && new_height > 0) {
                cv::resize(obj_image, obj_image, cv::Size(new_width, new_height), 0, 0, cv::INTER_AREA);
            }
            else {
                error_count_++;
                logger_->logError("Invalid dimensions after resizing object");
                continue;
            }
        }
            

        cv::Mat segmented = segmenter_->segmentImage(obj_image);

        if (segmented.empty()) {
            if (debug_preprocess_)
                logger_->logDebug("preprocess","Segmented image is empty after segmentation for object.");
            continue;
        }
        else {
            int newHeight = 16;
            double aspectRatio = static_cast<double>(segmented.cols) / static_cast<double>(segmented.rows);
            int newWidth = static_cast<int>(newHeight * aspectRatio);
            cv::Mat resizedImage;
            cv::resize(segmented, resizedImage, cv::Size(newWidth, newHeight));

            presend_images_.push_back(std::move(resizedImage));
            if (debug_preprocess_)
                logger_->logDebug("preprocess", "push sub image to presend images bank");
        }
        


    }
    if (debug_preprocess_)
        logger_->logDebug("preprocess", "Segment " + std::to_string(presend_images_.size()) + " objects");
    object_clips_.clear();
    current_state_ = State::CHECK_FPGA;
}

// CHECK_FPGA: status query, decide next step
void AlprStateMachine::handleCheckFpga() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter CheckFpga State.");
    // Query fpga_bridge_->getStatus()
    // Set flags, counters, handle repeat errors.
    // Set current_state_ to next state depending on FPGA status:
    // IDLE -> SEND_IMAGE
    // WAIT_ACK -> SEND_ACK
    // WAIT_TX -> RECEIVE_RESULT
    // ERROR_OVERFLOW -> SPLIT_BANKS
    // ERROR_OCR/overflow_flag -> RESET_FPGA
    // ERROR_TX/RX/COM -> MARGE_BANKS (or ERROR)
    // Others -> stay/check again
    fpga_status_ = fpga_bridge_->getStatus();
    if (debug_fpga_)
        logger_->logDebug("fpga", fpga_bridge_->getStatusString());
    bool same_State = fpga_status_prev_ == fpga_status_.fsm_state;
    if (same_State)
        same_state_count_++;
    else
    {
        same_state_count_ = 0;
        try_reset_ = false;
    }
    switch (fpga_status_.fsm_state)
    {
        case(FpgaFsmStatus::IDLE):
            current_state_ = State::SEND_IMAGE;
            same_state_count_ = 0;
            break;
        case(FpgaFsmStatus::WAIT_ACK):
            same_state_count_ = 0;
            current_state_ = State::SEND_ACK;
            break;
        case(FpgaFsmStatus::WAIT_TX):
            same_state_count_ = 0;
            current_state_ = State::RECEIVE_RESULT;
            break;
        case(FpgaFsmStatus::ERROR_OVERFLOW):
            if (same_state_count_ == max_fpga_persists_states_) {
                current_state_ = State::ERROR;
                logger_->logError("Critical Error: the system fail to reset from ERROR_OVERFLOW");
                break;
            }

            if (same_State){
                current_state_ = State::RESET_FPGA;
            }else{
                current_state_ = State::SPLIT_BANKS;
            }
            break;
        case(FpgaFsmStatus::ERROR_OCR):
            current_state_ = State::RESET_FPGA;
            break;
        case(FpgaFsmStatus::ERROR_TX):
            if (same_State){
                current_state_ = State::ERROR;
            }else{
                current_state_ = State::MARGE_BANKS;
            }
            break;
        case(FpgaFsmStatus::ERROR_RX):
            if (same_State){
                current_state_ = State::ERROR;
            }else{
                current_state_ = State::MARGE_BANKS;
            }
            break;
        case(FpgaFsmStatus::ERROR_COM):
            if (same_State){
                current_state_ = State::ERROR;
            }else{
                current_state_ = State::MARGE_BANKS;
            }
            break;
        case(FpgaFsmStatus::OFFLINE):
            if (same_state_count_ == max_fpga_persists_states_)
            {
                logger_->logError("Critical ERROR! FPGA fail to init after "+ std::to_string(same_state_count_) + "retry");
                error_count_++;
                current_state_ = State::ERROR;
            }else{ 
                if (!fpga_bridge_->cmdInit(min_digits_, max_digits_, watchdog_pio_, watchdog_ocr_, ocr_break_, ignore_invalid_cmd_))
                {
                    logger_->logError("FPGA fail to init, Retry");
                    error_count_++;
                    current_state_ = State::CHECK_FPGA;
                }
            }
        
            break;

        default:
            if (same_state_count_ >= max_fpga_persists_states_)
            {
                if (try_reset_)
                {
                    logger_->logError("Critical ERROR! FPGA got stuck on " + fpga_bridge_->getFsmStateName(fpga_status_.fsm_state) + "state for " + std::to_string(same_state_count_) + "tries and a reset");
                    error_count_++;
                    current_state_ = State::ERROR;
                }else{
                    try_reset_ = true;
                    current_state_ = State::RESET_FPGA;

                }
            }
            else
                current_state_ = State::FRAME_CUPTURE;
            break;
    }
    fpga_status_prev_ = fpga_status_.fsm_state;

}

// SEND_IMAGE: send prepared bank to FPGA
void AlprStateMachine::handleSendImage() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter SendImage State.");
    // Move prep bank to sended bank, send to FPGA.
    // Clear/refill prep bank.
    // Convert to vector<image> format
    std::vector<std::vector<std::vector<uint8_t>>> images;
    int total_images = presend_images_.size();
    if (total_images == 0)
    {

        current_state_ = State::FRAME_CUPTURE;
        return;
    }
    for (int i = 0; i < total_images; ++i) {
        int cols = presend_images_[i].cols;
        std::vector<std::vector<uint8_t>> single_img(16, std::vector<uint8_t>(cols));
        for (int y = 0; y < 16; ++y) {
            for (int x = 0; x < presend_images_[i].cols; ++x)
            {
                single_img[y][x] = presend_images_[i].at<uint8_t>(y, x);
            }
        }
        images.push_back(std::move(single_img));
    }
    if (!fpga_bridge_->sendImageStrip(images)) {
        logger_->logError("Fail to send image to fpga");
        error_count_++;

        current_state_ = State::CHECK_FPGA;
        return;
    }
    fpga_job_pending_ = true;
    sended_images_ = std::move(presend_images_);
    presend_images_.clear();

    if(debug_fpga_)
        logger_->logDebug("fpga", "Send images to fpga.");
    current_state_ = State::FRAME_CUPTURE;
}

// SEND_ACK: send ACK for empty result
void AlprStateMachine::handleSendAck() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter SendAck State.");
    // Send ACK command to FPGA.
    if (!fpga_bridge_->cmdAckIrq()) {
        logger_->logError("Fail to ack cmd to fpga");
        error_count_++;

        current_state_ = State::CHECK_FPGA;
        return;
    }
    fpga_job_pending_ = false;
    current_state_ = State::SEND_IMAGE;
}

// RECEIVE_RESULT: get OCR result from FPGA
void AlprStateMachine::handleReceiveResult() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter ReceiveResult State.");
    // fpga_bridge_->receiveResultStrings(...)
    // Store results for postprocess.
    if (!fpga_bridge_->receiveResultStrings(results_)) {
        logger_->logError("Fail to read result from FPGA");
        error_count_++;

        current_state_ = State::CHECK_FPGA;
        return;
    }
    current_state_ = State::POSTPROCESS;
}

// POSTPROCESS: dedup, filter, update log
void AlprStateMachine::handlePostprocess() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter Postprocess State.");
    // Filtered, deduplicated valid LPs for this frame
    std::vector<std::string> valid_lps;

    // Step 1: Validate and deduplicate
    for (const auto& lp : results_) {
        // 1. Filter LPs that start with '0'
        if (lp.empty() || lp[0] == '0')
            continue;

        // 2. Check for duplicate in last_lp_list_
        bool is_duplicate = false;
        for (const auto& prev_lp : last_lp_list_) {
            if (lp == prev_lp) {
                is_duplicate = true;
                break;
            }
        }
        if (is_duplicate)
            continue;

        // 3. This is a new, valid LP: add to current results and last_lp_list_
        valid_lps.push_back(lp);
        last_lp_list_.push_back(lp);
        // Keep last_lp_list_ size ≤ 30
        if (last_lp_list_.size() > 30)
            last_lp_list_.pop_front();
        // Update last_lp_
        last_lp_ = lp;
    }

    // Prepare a summary line for logging (all valid LPs joined by a space)
    std::string line_to_log;
    for (size_t i = 0; i < valid_lps.size(); ++i) {
        if (i > 0)
            line_to_log += ", ";
        line_to_log += valid_lps[i];
    }

    // Log the line if there are any new valid LPs
    if (!line_to_log.empty()) {
        logger_->addPlateLog(line_to_log);
        total_lp_count_ += valid_lps.size();
        if (debug_state_machine_)
            logger_->logDebug("state", "Logged LPs: " + line_to_log);
    }

    results_.clear(); // Always clear results buffer after processing
    current_state_ = State::SEND_ACK;
}

// RESET_FPGA: recover from error
void AlprStateMachine::handleResetFpga() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter ResetFpga State.");
    // Send reset command, clear any temp flags.
    if (!fpga_bridge_->cmdReset())
    {
        logger_->logError("Critical ERROR fail to reset fpga!");
        current_state_ = State::ERROR;
        return;
    }
    if (debug_fpga_)
        logger_->logDebug("fpga", "FPGA as been reset.");
    if (!fpga_bridge_->cmdInit(min_digits_, max_digits_, watchdog_pio_, watchdog_ocr_, ocr_break_, ignore_invalid_cmd_))
    {
        logger_->logError("FPGA fail to init");
        error_count_++;
        current_state_ = State::CHECK_FPGA;
        return;
    }
    if (debug_fpga_)
        logger_->logDebug("fpga", "FPGA as been init afte a reset.");
    fpga_job_pending_ = false;
    current_state_ = State::RESEND_IMAGE;
}

// SPLIT_BANKS: on overflow, split batch
void AlprStateMachine::handleSplitBanks() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter SplitBanks State.");
    // Split sended bank, move half to prep bank.
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter ResendImage State.");
    // Resend sended bank to FPGA.
    if (!fpga_bridge_->cmdReset())
    {
        logger_->logError("Critical ERROR fail to reset fpga!");
        current_state_ = State::ERROR;
        return;
    }
    if (debug_fpga_)
        logger_->logDebug("fpga", "FPGA as been reset.");
    if (!fpga_bridge_->cmdInit(min_digits_, max_digits_, watchdog_pio_, watchdog_ocr_, ocr_break_, ignore_invalid_cmd_))
    {
        logger_->logError("FPGA fail to init");
        error_count_++;
        current_state_ = State::CHECK_FPGA;
        return;
    }
    if (debug_fpga_)
        logger_->logDebug("fpga", "FPGA as been init afte a reset.");


    //Start split presend_images bank and resending them back

    int total_images = presend_images_.size();
    if (total_images == 0) {
        current_state_ = State::FRAME_CUPTURE;
        return;
    }
    int half = total_images / 2;
    for (int i = 0; i < half; ++i) {
        sended_images_.push_back(std::move(presend_images_[i]));
    }
    std::vector<cv::Mat> fpga_images;
    for (int i = half; i < total_images; ++i) {
        fpga_images.push_back(std::move(presend_images_[i]));
    }

    presend_images_.clear();
    std::vector<std::vector<std::vector<uint8_t>>> images;
    for (const auto& img : fpga_images) {
        int cols = img.cols;
        std::vector<std::vector<uint8_t>> single_img(16, std::vector<uint8_t>(cols));
        for (int y = 0; y < 16; ++y) {
            for (int x = 0; x < cols; ++x) {
                single_img[y][x] = img.at<uint8_t>(y, x);
            }
        }
        images.push_back(std::move(single_img));
    }
    if (!fpga_bridge_->sendImageStrip(images)) {
        logger_->logError("Fail to send image to fpga");
        error_count_++;

        current_state_ = State::CHECK_FPGA;
        return;
    }
    fpga_job_pending_ = true;

    current_state_ = State::FRAME_CUPTURE;
}

// MARGE_BANKS: on comm error, merge/flush banks
void AlprStateMachine::handleMargeBanks() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter MargeBanks State.");
    // Merge sended + prep banks, try resending.
    // Resend sended bank to FPGA.
    if (!fpga_bridge_->cmdReset())
    {
        logger_->logError("Critical ERROR fail to reset fpga!");
        current_state_ = State::ERROR;
        return;
    }
    if (debug_fpga_)
        logger_->logDebug("fpga", "FPGA as been reset.");
    if (!fpga_bridge_->cmdInit(min_digits_, max_digits_, watchdog_pio_, watchdog_ocr_, ocr_break_, ignore_invalid_cmd_))
    {
        logger_->logError("FPGA fail to init");
        error_count_++;
        current_state_ = State::CHECK_FPGA;
        return;
    }
    if (debug_fpga_)
        logger_->logDebug("fpga", "FPGA as been init afte a reset.");


    //Start marging bank and resending them back
    sended_images_ = std::move(presend_images_);
    presend_images_.clear();

    std::vector<std::vector<std::vector<uint8_t>>> images;
    int total_images = sended_images_.size();
    if (total_images == 0)
    {

        current_state_ = State::FRAME_CUPTURE;
        return;
    }
    for (int i = 0; i < total_images; ++i) {
        int cols = sended_images_[i].cols;
        std::vector<std::vector<uint8_t>> single_img(16, std::vector<uint8_t>(cols));
        for (int y = 0; y < 16; ++y) {
            for (int x = 0; x < sended_images_[i].cols; ++x)
            {
                single_img[y][x] = sended_images_[i].at<uint8_t>(y, x);
            }
        }
        images.push_back(std::move(single_img));
    }
    if (!fpga_bridge_->sendImageStrip(images)) {
        logger_->logError("Fail to send image to fpga");
        error_count_++;

        current_state_ = State::CHECK_FPGA;
        return;
    }
    fpga_job_pending_ = true;
    
    current_state_ = State::FRAME_CUPTURE;
}

// HALT: end-of-service
void AlprStateMachine::handleHalt() {
    if (debug_state_machine_)
        logger_->logDebug("state", "System FSM enter HALT State.");
    logger_->logMsg("FSM received HALT. Exiting run loop.");
    running_lcd_status_ = LcdStatus::Offline;
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    if (lcd_)lcd_.update("--------", 0, 0, 0, 0, LcdStatus::Offline);
    fpga_bridge_->cmdReset();
    logger_->forceFlushLog();
    logger_->forceFlushPlate();
    running_ = false;
}

// ERROR: fatal error handler
void AlprStateMachine::handleError() {
    logger_->logError("ALPR SYSTEM entered Critical ERROR state.");
    running_lcd_status_ = LcdStatus::Error;
    // Log and halt system or escalate.
    running_ = false;
}

void AlprStateMachine::updateSystemStatus() {
    if(logger_)
        logger_->maybeFlushLog();
    // Snapshot the current FSM state
    fsm_status_snapshot_ = current_state_;

    auto now = std::chrono::steady_clock::now();

    // Detect LCD status change and reset duration timer if needed
    if (last_status_lcd_ != running_lcd_status_) {
        last_status_lcd_ = running_lcd_status_;
        status_start_time = now;
    }

    // Update status duration
    status_duration_seconds_ = std::chrono::duration_cast<std::chrono::seconds>(
        now - status_start_time
    ).count();

    // Update LCD (or other UI) if enough time has passed
    auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_lcd_update_).count();
    if (lcd_en_ && elapsed_ms >= LCD_UPDATE_INTERVAL_MS) {
        lcd_.update(last_lp_, fps_, total_lp_count_, error_count_, status_duration_seconds_, running_lcd_status_);
        last_lcd_update_ = now;
    }
}
