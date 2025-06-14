# ⚙️ ALPR_SYSTEM Configuration Reference

This document describes the configuration file used to initialize the ALPR system. Parameters control the behavior of the FSM, FPGA communication, model loading, logging, and operational modes.

---

## 📁 Config File

- Defualt value are set in `ALPR_SYSTEM/src/default_config.hpp`
- Default path: `/etc/alpr/alpr_config.ini`
- Generated on first run if missing
- Values are parsed as key-value pairs (e.g., `key=value`)

---

## 🔧 General System Settings

| Key                           | Type   | Default         | Description                                                |
|-------------------------------|--------|------------------|------------------------------------------------------------|
| `mode`                        | string | `folder`         | Input mode: `camera` or `folder`                           |
| `input_path`                  | string | `./input`        | Path to folder if in `folder` mode                         |
| `lcd`                         | bool   | `true`           | Enable LCD output (if available)                           |
| `demo_mode`                   | bool   | `false`          | Use folder fallback if camera fails                        |
| `max_persists_empty_frames`   | int    | `10`             | Max blank frames before camera is considered dead          |
| `max_fpga_persists_states`    | int    | `5`              | Max retries of a stuck FPGA FSM state before error         |

---

## 🧠 NanoDet Model Settings

| Key                    | Type   | Default            | Description                                 |
|------------------------|--------|--------------------|---------------------------------------------|
| `model.param_path`     | string | `./model.param`    | Path to NanoDet `.param` file               |
| `model.bin_path`       | string | `./model.bin`      | Path to NanoDet `.bin` file                 |
| `model.num_threads`    | int    | `2`                | Number of inference threads                 |
| `model.targer_size`    | int    | `320`              | Image resize target before detection        |
| `model.prob_threshold` | float  | `0.4`              | Confidence threshold for detection          |
| `model.nms_threshold`  | float  | `0.3`              | NMS threshold for box suppression           |

---

## 🛰️ FPGA Bridge Settings

| Key                         | Type   | Default         | Description                                           |
|-----------------------------|--------|------------------|-------------------------------------------------------|
| `fpga.unsafe_mode`          | bool   | `false`          | Disable safety checks for testing                     |
| `fpga.timeout_cycles`       | int    | `5000`           | Timeout threshold (in FPGA clock cycles)              |
| `fpga.min_digits`           | int    | `4`              | Minimum plate digits expected                         |
| `fpga.max_digits`           | int    | `8`              | Maximum plate digits supported                        |
| `fpga.ocr_break`            | bool   | `false`          | Stop on first valid OCR result                        |
| `fpga.ignore_invalid_cmd`   | bool   | `false`          | Skip bad FPGA commands silently                       |
| `fpga.watchdog_pio`         | int    | `100`            | Watchdog timeout for PIO (raw uint8_t)                |
| `fpga.watchdog_ocr`         | int    | `100`            | Watchdog timeout for OCR FSM (raw uint8_t)            |

---

## 📚 Logging Configuration

| Key                        | Type   | Default        | Description                                     |
|----------------------------|--------|----------------|-------------------------------------------------|
| `log_dir`                  | string | `./logs`       | Directory for runtime logs                      |
| `log_rotation_hours`       | int    | `2`            | Number of hours per log file                    |
| `log_max_size_mb`          | int    | `5`            | Maximum size before rotating                    |
| `log_save_interval_sec`    | int    | `60`           | Flush interval (in seconds)                     |
| `log_max_entries`          | int    | `1000`         | Buffer size before flushing                     |
| `log_status`               | bool   | `true`         | Enable hourly status log output                 |
| `log_status_interval_min`  | int    | `60`           | Minutes between status auto-logs                |

---

## 📋 Plate Log Settings

| Key                         | Type   | Default        | Description                                      |
|-----------------------------|--------|----------------|--------------------------------------------------|
| `plate_dir`                 | string | `./plates`     | Directory for OCR plate logs                     |
| `plate_rotation_hours`      | int    | `2`            | Rotate every N hours                             |
| `plate_max_size_mb`         | int    | `5`            | Maximum log file size before rotation            |
| `plate_save_interval_sec`   | int    | `60`           | Save plate buffer to disk every N seconds        |
| `plate_max_entries`         | int    | `500`          | Flush buffer after this many entries             |

---

## 🐞 Debug Options

| Key                      | Type  | Default  | Description                                                                 |
|--------------------------|-------|----------|-----------------------------------------------------------------------------|
| `debug.deep`             | bool  | `false`  | Enable verbose subsystem debug output (may include raw image data/debug prints; **not guaranteed to be logged**) |
| `debug.state_machine`    | bool  | `false`  | Trace FSM transitions and state entry points                                |
| `debug.preprocess`       | bool  | `false`  | Show detection & segmentation steps                                         |
| `debug.fpga`             | bool  | `false`  | Log FPGA bridge communication activity                                      |

---

## 📝 Notes

- Boolean values are accepted as `true/false`
- All file paths are relative unless given absolute
- If the config file is missing and service is in daemon mode, it will auto-generate one using the defaults
- You can always regenerate the default config using `generateDefaultConfig()` at runtime

---

*This document describes the expected structure and default values of the ALPR system's configuration file.*
