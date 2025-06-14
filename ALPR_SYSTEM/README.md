# 🚦 ALPR_SYSTEM – Real-Time FPGA-Accelerated License Plate Recognition

This is the main control module of the ALPR system. It coordinates input capture, object detection, FPGA OCR acceleration, logging, and fault recovery — all through a robust finite state machine (FSM). The system is engineered for real-time, autonomous deployment on embedded Linux devices.

---

## 🧠 Core Responsibilities

- Capture frames from live camera or folder
- Detect license plates using NanoDet (via ncnn)
- Segment plates and send them to the FPGA for digit OCR
- Log all results and system status with auto-rotation
- Monitor and recover from camera or FPGA failures
- Respond to external commands via a thread-safe socket interface

---

## 📦 Directory Overview

| Path                          | Description                                                |
|-------------------------------|------------------------------------------------------------|
| `main.cpp`                    | Application entry point; starts FSM and socket server      |
| `alpr_statemachine.hpp/cpp`   | Full FSM logic, including error handling and recovery      |
| `default_config.hpp`          | Default config values auto-generated on first run         |
| `logger.hpp/cpp`              | Logging, plate storage, rotation handling                 |
| `ipc_shared.hpp`              | Shared control flags between socket and FSM               |
| `socket_server.hpp/cpp`       | Lightweight socket server (UNIX domain socket)            |
| `docs/`                       | FSM flow, config keys, recovery tree, and logs            |

---

## 🔁 FSM-Controlled Pipeline

```
[ Camera / Folder Input ]
            ↓
[ FSM Controller (alpr_statemachine.cpp) ]
    ├── DETECTION (NanoDet)
    ├── SEGMENATION
    ├── CHECK_FPGA
    ├── SEND_IMAGE → FPGA OCR
    ├── RECEIVE_RESULT ←
    ├── POSTPROCESS
    └── Logging + ACK
```

- The FSM owns all system state and flow
- All recovery logic is embedded inside state transitions

---

## 📡 Command Interface (via Socket)

- The ALPR system runs a **UNIX domain socket** server (`/run/alpr_system.sock`)
- It listens for commands from the CLI tool `alprcrtl`, hosted separately in the repo
- The socket thread **never directly touches the FSM** — instead:
  - It raises internal **tag toggles** (like `requestStop`, `requestRestart`)
  - These toggles are read **safely at the beginning of the FSM loop**
  - Ensures thread-safe control without race conditions

### Supported commands:

```bash
status     # Snapshot of current FSM state, uptime, FPS, last LP
stop       # Cleanly stop the system (FSM will exit safely)
restart    # Reinit FSM without rebooting system
flushlogs  # Force logs and plates to be flushed to disk
help       # List commands
```

Example usage (from a terminal or script):

```bash
alprctl status
```

> The `alprctl` CLI is documented separately under [`alprctl/README.md`](.././alprctl/README.md).

---

## ⚙️ Build Setup

- Built using **Visual Studio** with **remote Linux target deployment**

### Required on the target system:
- `OpenCV` – image input and capture
- `ncnn` – NanoDet inference

---

## 🧾 Example Output

Plate recognition:
```
2025-06-10 14:38:25 [PLATE] 5142616
```

Hourly status report:
```
2025-06-10 10:38:25 [INFO] Auto status report | FSM state: SEGMENATION, Running: 03:59:58
FPS: 16.7, Errors: 24, Total LPs: 4, Last: 5142616, Mode: folder
```

---

## 📑 Additional Documentation

| Topic                      | Path                                                              |
|----------------------------|-------------------------------------------------------------------|
| FSM pipeline overview      | [`docs/fsm_pipeline_overview.md`](./docs/fsm_pipeline_overview.md) |
| FPGA error recovery tree   | [`docs/fpga_system_fsm_recovery.md`](./docs/fpga_system_fsm_recovery.md) |
| Config keys + defaults     | [`docs/config_reference.md`](./docs/config_reference.md)         |
| Runtime health logs        | [`docs/runtime_status_logs/`](./docs/runtime_status_logs/)       |
| FPGA bridge protocol       | [`FPGA_HPS_Bridge_AHIM/docs/protocol/FPGA_HPS_Bridge_AHIM_protocol.md`](.././FPGA_HPS_Bridge_AHIM/docs/protocol/FPGA_HPS_Bridge_AHIM_protocol.md) |
| Deamon serivce       | [`docs/deamon/alpr_system.service`](./docs/deamon/alpr_system.service) |


---

## 🛑 Shutdown and Recovery

- PID file is written to `/run/alpr_system.pid`
- Auto cleanup on SIGINT, SIGTERM, or `stop` command
- FPGA is reset and logs are flushed during shutdown

---

*This service acts as the central runtime engine of the ALPR platform — managing inputs, orchestrating modules, handling errors, and interfacing with both hardware and CLI tools.*
