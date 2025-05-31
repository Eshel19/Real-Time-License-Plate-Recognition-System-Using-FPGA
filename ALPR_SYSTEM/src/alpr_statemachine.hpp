#pragma once
// alpr_statemachine.hpp
#pragma once

#include "config.hpp"
#include "logger.hpp"
#include <iostream>
#include <vector>
#include <cstdint>
#include <fstream>
#include <sys/types.h>
#include <unistd.h>
#include <ctime>
#include <string>
#include <memory>
#include <opencv2/opencv.hpp>
#include "preprocess_api/ImageSegmenter.h"
#include "preprocess_api/nanodet_ncnn.h"
#include "fpga_access_api/fpga_ocr_bridge.hpp"
#include <mutex>
#include <chrono>


#include "HPS_LCD/lcd_live_display.h"


class AlprStateMachine {
public:
    enum class State {
        INIT,
        BEGIN,
        HALT,
        ERROR
    };

    std::string getStatusSnapshot();
    AlprStateMachine(const Config& cfg, bool service_mode, std::shared_ptr<Logger> logger);
    ~AlprStateMachine();
    bool run();            
    void requestStop();    
    bool isRunning();

private:
    //FSM function:
    bool handleInit();
    std::string stateToString(State state);

    //Parameters
    std::shared_ptr<Logger> logger_;
    Config config_;
    bool is_service_;
    State current_state_;
    
    bool running_;
    std::mutex mutex_;

    //status_copy
    State fsm_status_snapshot_;


    //LCD 
    LcdLiveDisplay lcd_;
    std::string last_lp_ = "--------";
    float fps_=0;
    float avg_lp_time_ms_=0;
    uint32_t frame_lp_count_=0;
    uint32_t total_lp_count_=0;
    uint32_t error_count_=0;
    LcdLiveDisplay::LcdStatus running_lcd_status_= LcdLiveDisplay::LcdStatus::Paused;
    std::chrono::steady_clock::time_point last_lcd_update_;
    static constexpr int LCD_UPDATE_INTERVAL_MS = 100;

    // General settings
    std::string run_mode_;
    std::string input_path_;
    bool repeat_folder_ = false;

    // Debug settings
    bool debug_deep_ = false;
    bool debug_state_machine_ = true;
    bool debug_preprocess_ = true;
    bool debug_detection_ = false;
    bool debug_fpga_ = false;
    bool debug_transfer_ = false;

    // FPGA settings
    bool unsafe_mode_ = false;
    uint32_t timeout_cycles_ = 1000;
    uint8_t min_digits_ = 7;
    uint8_t max_digits_ = 8;
    uint8_t watchdog_pio_ = 20;
    uint8_t watchdog_ocr_ = 200;
    bool ocr_break_ = false;
    bool ignore_invalid_cmd_ = false;

    // Plate logging settings
    std::string plate_dir_;
    int plate_rotation_hours_ = 1;
    int plate_max_size_mb_ = 15;
    int plate_save_interval_sec_ = 60;
    int plate_max_entries_ = 3000;

    // System log settings
    std::string log_dir_;
    int log_rotation_hours_ = 2;
    int log_max_size_mb_ = 2;
    int log_save_interval_sec_ = 30;
    int log_max_entries_ = 200;
    
    // NCNN model config
    std::string model_param_path_;
    std::string model_bin_path_;
    int model_num_threads_ = 2;
    int model_target_size_ = 128;
    float model_prob_threshold_ = 0.6f;
    float model_nms_threshold_ = 0.65f;

    //preprocess classes
    std::unique_ptr<NanoDet> detector_;
    cv::VideoCapture cap_;
    ImageSegmenter segmenter_;
    
    //bridge access
    std::unique_ptr<FpgaOcrBridge> fpga_bridge_;
};
