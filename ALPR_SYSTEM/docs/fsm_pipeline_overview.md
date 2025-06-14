# 📘 FSM Pipeline Overview – ALPR_SYSTEM

This document describes the full operational pipeline of the ALPR Finite State Machine (FSM), from initialization to shutdown, and how it integrates with core components such as the logger, config, LCD, camera/folder input, FPGA bridge, and command socket interface.

---

## 🔧 System Entry Point

The `main.cpp` file initializes the ALPR system and handles:
- PID lock file creation
- Signal handling (SIGINT/SIGTERM)
- Daemon/service mode detection
- Instantiation of:
  - `AlprStateMachine`
  - `Logger`
  - `SocketServer`
- Socket command mapping ("stop", "status", "restart", "flushlogs")
- Main FSM loop execution via `fsm->run()`

---

## 🚦 FSM Core Flow (High-Level)

### State List
| FSM State        | Description                                        |
|------------------|----------------------------------------------------|
| `INIT`           | Load config, initialize logger, model, FPGA        |
| `FRAME_CUPTURE`  | Acquire frame from camera or folder input         |
| `DETECTION`      | Run NanoDet object detection                      |
| `SEGMENATION`    | Segment LP images from detections                 |
| `CHECK_FPGA`     | Query FPGA state and determine next action        |
| `SEND_IMAGE`     | Send images to FPGA input buffer                  |
| `RECEIVE_RESULT` | Retrieve OCR results from FPGA                    |
| `POSTPROCESS`    | Deduplicate and validate detected license plates  |
| `SEND_ACK`       | Acknowledge FPGA state if no results              |
| `RESET_FPGA`     | Reset and reinitialize FPGA state machine         |
| `SPLIT_BANKS`    | Handle bank overflow by splitting image batches   |
| `MARGE_BANKS`    | Recombine buffers after transmission failure      |
| `HALT`           | Clean shutdown                                    |
| `ERROR`          | Fatal failure and shutdown                        |

---



## 🔁 FSM State Transition Table

| Current State      | Event / Condition                            | Next State        | Action Taken                                     |
|--------------------|----------------------------------------------|-------------------|--------------------------------------------------|
| `INIT`             | Config valid, components initialized         | `FRAME_CUPTURE`   | Log startup, init detector, FPGA, etc.           |
| `INIT`             | Config error or user abort                   | `ERROR`           | Log and abort                                    |
| `FRAME_CUPTURE`    | Frame acquired from camera/folder            | `DETECTION`       | Log + store image                                |
| `FRAME_CUPTURE`    | Frame empty & recovery failed                | `ERROR` / `folder`| Try reopen or fallback to folder mode            |
| `DETECTION`        | LPs detected                                 | `SEGMENATION`     | Extract ROIs from frame                          |
| `DETECTION`        | No LPs & FPGA job pending                    | `CHECK_FPGA`      | Continue checking FPGA                           |
| `DETECTION`        | No LPs & idle                                | `FRAME_CUPTURE`   | Skip frame                                       |
| `SEGMENATION`      | At least 1 valid segment                     | `CHECK_FPGA`      | Resize + prepare image bank                      |
| `SEGMENATION`      | No valid segments                            | `FRAME_CUPTURE`   | Skip                                             |
| `CHECK_FPGA`       | FPGA state = IDLE                            | `SEND_IMAGE`      | Prepare and send                                 |
| `CHECK_FPGA`       | FPGA state = WAIT_TX                         | `RECEIVE_RESULT`  | Receive OCR result                               |
| `CHECK_FPGA`       | FPGA state = WAIT_ACK                        | `SEND_ACK`        | Acknowledge IRQ                                  |
| `CHECK_FPGA`       | FPGA state = ERROR_XXX                       | `RESET_FPGA` / `ERROR` | Recovery logic depending on repeat              |
| `SEND_IMAGE`       | Send success                                 | `FRAME_CUPTURE`   | Push images and wait                             |
| `SEND_IMAGE`       | Send failed                                  | `CHECK_FPGA`      | Retry                                            |
| `RECEIVE_RESULT`   | Result received                              | `POSTPROCESS`     | Parse and hold LP strings                        |
| `RECEIVE_RESULT`   | Fail                                         | `CHECK_FPGA`      | Retry                                            |
| `POSTPROCESS`      | Done                                         | `SEND_ACK`        | Deduplicate, log LPs                             |
| `SEND_ACK`         | Ack success                                  | `SEND_IMAGE`      | Allow next job                                   |
| `RESET_FPGA`       | Reset + init success                         | `SEND_IMAGE` / `FRAME_CUPTURE` | Continue based on pending job         |
| `RESET_FPGA`       | FPGA reset fail                              | `ERROR`           | Abort                                            |
| `SPLIT_BANKS`      | Split + resend success                       | `FRAME_CUPTURE`   | Resend smaller job                               |
| `SPLIT_BANKS`      | Fail                                         | `ERROR`           | Abort                                            |
| `MARGE_BANKS`      | Retry merged job success                     | `FRAME_CUPTURE`   | Continue                                         |
| `MARGE_BANKS`      | Fail                                         | `ERROR`           | Abort                                            |
| `ERROR`            | Any                                          | HALT              | Log + exit cleanly                               |
| `HALT`             | System shutting down                         | --                | FPGA reset, log flush                            |

## 📂 Subsystem Roles

### 🧠 AlprStateMachine
- Owns the current FSM state (`current_state_`)
- Manages all processing from frame to OCR result
- Calls FPGA API functions (`cmdReset`, `sendImageStrip`, `receiveResultStrings`)
- Issues timed status reports via `logger->logMsg()`

### 📝 Logger
- Controlled by config options:
  - `log_dir`, `log_rotation_hours`, `log_status`, etc.
- Periodically flushes:
  - System logs
  - Plate result logs
- Outputs structured log entries and status reports

### ⚙️ Config
- Loaded on `INIT` via `.ini`-like file
- Handles:
  - Debug toggles
  - Input mode (`camera`, `folder`)
  - Logger & plate log settings
  - FPGA parameter config
  - NCNN model paths

### 📷 Input Mode
- Controlled by `mode=camera` or `mode=folder`
- If `demo_mode=true`, system will auto-recover from camera failure and switch to folder input

### 📡 FPGA Bridge
- Initialized on startup
- Used to:
  - Send image strips (`sendImageStrip`)
  - Reset/init state (`cmdReset`, `cmdInit`)
  - Retrieve results (`receiveResultStrings`)
  - Report status (`getStatus`)

### 📺 LCD Display (if enabled)
- Updates at a fixed interval with:
  - FPS
  - LP count
  - Error count
  - System status (`Running`, `Paused`, etc.)

### 🧵 SocketServer
- Handles external control via UNIX socket
- Commands:
  - `status`, `stop`, `restart`, `flushlogs`, `help`
- Integrates with FSM and Logger via `std::function` map

---

## 🔁 Runtime Loop – `fsm->run()`

1. Lock mutex and check flags  
2. If restart requested → `resetStateMachine()`  
3. If `request_flash_log_` → flush logs  
4. Update LCD + status interval logging  
5. Based on `current_state_`:  
   - Execute corresponding handler (e.g., `handleDetection()`)  
6. Repeat while `running_ == true`

---

## 🧼 Shutdown Flow

- `handleSignal()` triggers on SIGINT/SIGTERM  
- PID file removed  
- FSM enters `HALT`  
- LCD set to `Offline`  
- FPGA reset  
- Logs forcibly flushed  
- Socket shutdown  

---

## 🔗 Related Documentation

This document focuses exclusively on the control flow, runtime behavior, and structure of the FSM (Finite State Machine) component within the ALPR system.

For related system documentation, refer to:

- [`fpga_system_fsm_recovery.md`](./fpga_system_fsm_recovery.md) – FPGA error handling and fallback logic
- [`runtime_status_logs/`](./runtime_status_logs/) – Hourly FSM-generated logs for monitoring uptime and performance

---

*This file is part of the internal documentation set for the ALPR system. It covers only the FSM logic and its runtime flow.*

