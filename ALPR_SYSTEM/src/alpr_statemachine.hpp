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
#include "ipc_shared.hpp"
#include "default_config.hpp"

using LcdStatus = LcdLiveDisplay::LcdStatus;
using FpgaFsmStatus = FpgaOcrBridge::FsmState;
using OcrStatus = FpgaOcrBridge::OcrStatus;
namespace fs = std::filesystem;

class AlprStateMachine {
public:
    enum class State {
        INIT,
        FRAME_CUPTURE,
        DETECTION,
        SEGMENATION,
        CHECK_FPGA,
        SEND_IMAGE,
        SEND_ACK,
        POSTPROCESS,
        RECEIVE_RESULT,
        RESET_FPGA,
        SPLIT_BANKS,
        MARGE_BANKS,
        RESEND_IMAGE,
        HALT,
        ERROR
    };

    std::string getStatusSnapshot();
    AlprStateMachine(const Config& cfg, bool service_mode, std::shared_ptr<Logger> logger);
    ~AlprStateMachine();
    bool run();            
    void requestStop();    
    void requestRestart();
    bool isRunning();
    std::string requestFlashLogs();

private:
    //FSM handlers:
    bool handleInit();
    void handleFrameCapture();
    void handleDetection();
    void handleSegmenation();
    void handleCheckFpga();
    void handleSendImage();
    void handleSendAck();
    void handlePostprocess();
    void handleReceiveResult();
    void handleResetFpga();
    void handleSplitBanks();
    void handleMargeBanks();
    void handleHalt();
    void handleError();
    void updateSystemStatus();

    std::string stateToString(State state);
    bool generateDefaultConfig(const std::string& path);
    void resetStateMachine();
    std::string getStatus_();


    //Parameters
    std::shared_ptr<Logger> logger_;
    Config config_;
    bool is_service_;
    State current_state_;
    std::chrono::steady_clock::time_point status_start_time;
    uint32_t max_persists_empty_frames_ = 10;
    bool running_;
    std::mutex mutex_;
    int max_fpga_persists_states_ = 5;
    bool demo_mode_ = false;
    bool fsm_restart_requested_ = false;
    bool request_stop_ = false;
    bool request_flash_log_ = false;
    //status_copy
    State fsm_status_snapshot_;

    //ERROR FLAGS
    bool try_reset_ = false;
    
    // Frame buffer
    cv::Mat current_frame_;
    std::vector<cv::Mat> object_clips_;
    std::chrono::steady_clock::time_point last_frame_time_;
    std::chrono::steady_clock::time_point fps_window_start_time_;
    uint32_t empty_frame_ = 0;
    int fps_window_frame_count_ = 0;
    static constexpr float FPS_WINDOW_SEC = 1.0f; // 1 second window (can be 2.0f, etc)

    // Results buffer
    std::vector<std::string> folder_image_list_;
    size_t folder_image_idx_ = 0;
    std::vector<std::string> fpga_results_;
    bool fpga_job_pending_ = false;

    // Deduplication
    std::deque<std::string> last_lp_list_;

    // Results buffer
    std::vector<cv::Mat> presend_images_;
    std::vector<cv::Mat> sended_images_;
    OcrStatus fpga_status_;
    FpgaFsmStatus fpga_status_prev_=FpgaFsmStatus::IDLE;
    int same_state_count_ = 0;
    std::vector<std::string> results_;

    //LCD 
    LcdLiveDisplay lcd_;
    std::string last_lp_ = "--------";
    float fps_=0;
    uint32_t total_lp_count_=0;
    uint32_t error_count_=0;
    uint32_t status_duration_seconds_=0;
    LcdStatus running_lcd_status_= LcdStatus::Paused;
    LcdStatus last_status_lcd_ = LcdStatus::Offline;
    std::chrono::steady_clock::time_point last_lcd_update_;
    static constexpr int LCD_UPDATE_INTERVAL_MS = 100;

    // General settings
    std::string run_mode_;
    std::string input_path_;
    bool repeat_folder_ = false;
    bool lcd_en_ = false;

    // Debug settings
    bool debug_deep_ = false;
    bool debug_state_machine_ = false;
    bool debug_preprocess_ = false;
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
    bool log_status_ = true;
    int log_status_interval_min_ = 60;
    std::chrono::steady_clock::time_point last_log_status_time_;

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
    std::unique_ptr<ImageSegmenter> segmenter_;
    
    //bridge access
    std::unique_ptr<FpgaOcrBridge> fpga_bridge_;
};
