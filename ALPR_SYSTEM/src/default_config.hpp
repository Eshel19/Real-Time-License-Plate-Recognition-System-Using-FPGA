// default_config.hpp
#pragma once

// General
constexpr const char* DEF_MODE = "camera";
constexpr const char* DEF_INPUT_PATH = "/home/DE10/projects/demo";
constexpr bool   DEF_LCD = true;
constexpr bool   DEF_DEMO_MODE = true;
constexpr int    DEF_MAX_PERSISTS_EMPTY_FRAMES = 10;
constexpr int    DEF_MAX_FPGA_PERSISTS_STATES = 5;

// Nanodet model config
constexpr const char* DEF_MODEL_PARAM_PATH = "/etc/alpr_system/nanodet.param";
constexpr const char* DEF_MODEL_BIN_PATH = "/etc/alpr_system/nanodet.bin";
constexpr int    DEF_MODEL_NUM_THREADS = 2;
constexpr int    DEF_MODEL_TARGET_SIZE = 128;
constexpr char* DEF_MODEL_PROB_THRESHOLD = "0.6";
constexpr char* DEF_MODEL_NMS_THRESHOLD = "0.65";

// FPGA bridge config
constexpr bool   DEF_FPGA_UNSAFE_MODE = false;
constexpr int    DEF_FPGA_TIMEOUT_CYCLES = 1000;
constexpr int    DEF_FPGA_MIN_DIGITS = 7;
constexpr int    DEF_FPGA_MAX_DIGITS = 8;
constexpr bool   DEF_FPGA_OCR_BREAK = false;
constexpr bool   DEF_FPGA_IGNORE_INVALID_CMD = false;
constexpr int    DEF_FPGA_WATCHDOG_PIO = 20;
constexpr int    DEF_FPGA_WATCHDOG_OCR = 200;

// Debugging
constexpr bool   DEF_DEBUG_DEEP = false;
constexpr bool   DEF_DEBUG_STATE_MACHINE = false;
constexpr bool   DEF_DEBUG_PREPROCESS = false;
constexpr bool   DEF_DEBUG_FPGA = false;

// Logging
constexpr const char* DEF_LOG_DIR = "/var/log/alpr_system/logs";
constexpr int    DEF_LOG_ROTATION_HOURS = 2;
constexpr int    DEF_LOG_MAX_SIZE_MB = 2;
constexpr int    DEF_LOG_SAVE_INTERVAL_SEC = 30;
constexpr int    DEF_LOG_MAX_ENTRIES = 200;
constexpr bool   DEF_LOG_STATUS = true;
constexpr int    DEF_LOG_STATUS_INTERVAL_MIN = 60;

// Plate result logging
constexpr const char* DEF_PLATE_DIR = "/var/log/alpr_system/plates";
constexpr int    DEF_PLATE_ROTATION_HOURS = 1;
constexpr int    DEF_PLATE_MAX_SIZE_MB = 15;
constexpr int    DEF_PLATE_SAVE_INTERVAL_SEC = 60;
constexpr int    DEF_PLATE_MAX_ENTRIES = 3000;
