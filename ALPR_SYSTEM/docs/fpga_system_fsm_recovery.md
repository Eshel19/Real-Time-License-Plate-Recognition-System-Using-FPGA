# 📘 Full System FSM & FPGA Error Recovery Documentation

## 🧠 Overview

This document outlines the complete FSM (Finite State Machine) flow of the ALPR system and details the FPGA error handling and recovery strategy. The design ensures real-time operation with robust fault tolerance across both software and hardware boundaries.

---

## 📍 1. FSM Main States

| FSM State        | Description                            |
|------------------|----------------------------------------|
| `FRAME_CAPTURE`  | Capture frame from camera or folder    |
| `DETECTION`      | Run NanoDet object detection           |
| `SEGMENATION`    | Segment LP images from detection       |
| `CHECK_FPGA`     | Poll FPGA state and decide next action |
| `SEND_IMAGE`     | Send segmented images to FPGA          |
| `RECEIVE_RESULT` | Receive OCR results                    |
| `POSTPROCESS`    | Deduplicate and filter final LPs       |
| `SEND_ACK`       | Acknowledge empty results              |
| `RESET_FPGA`     | Attempt recovery                       |
| `SPLIT_BANKS`    | Bank too large, split batch            |
| `MARGE_BANKS`    | Combine and resend                     |
| `ERROR`          | Fatal, unrecoverable state             |
| `HALT`           | Service shutdown                       |

---

## ⚠️ 2. Error Entry Points

| Location          | Error Type                    | Recovery/Fallback Path              |
|-------------------|-------------------------------|-------------------------------------|
| `FRAME_CAPTURE`   | Camera frame empty            | Try reopen, fallback to folder/demo |
| `DETECTION`       | No LPs found                  | Skip to next frame or CHECK_FPGA    |
| `SEGMENATION`     | Invalid or empty segmentation | Skip current object                 |
| `SEND_IMAGE`      | FPGA send fails               | Go to CHECK_FPGA                    |
| `RECEIVE_RESULT`  | Receive from FPGA fails       | Go to CHECK_FPGA                    |
| `CHECK_FPGA`      | Handles all FPGA FSM errors   | Tiered fallback logic               |
| `RESET_FPGA`      | Reset fails                   | Escalate to ERROR                   |
| `SPLIT_BANKS`     | Reset fails or resend fails   | Escalate to ERROR                   |
| `MARGE_BANKS`     | Reset or resend fails         | Escalate to ERROR                   |
| `cmdInit()` fails | FPGA init fails               | Retry until threshold, then ERROR   |

---

## 🔁 3. Global Recovery Strategy

Every critical operation has 3 fallback levels:

1. 🔁 **Retry or alternate action**
2. 🔧 **Reset and reinit subsystem**
3. ❌ **Declare critical error (FSM enters ERROR)**

---

## 🔄 4. Master FSM Flow (Top-Down)

```
SYSTEM START →
FRAME_CAPTURE
├─ Camera OK → continue
└─ Frame Empty?
├─ Retry camera
├─ If fail → demo mode?
│ ├─ Yes → switch to folder mode
│ └─ No → enter ERROR
└─ Recovered → continue

DETECTION
├─ No LPs?
│ ├─ fpga_job_pending_ → CHECK_FPGA
│ └─ otherwise → FRAME_CAPTURE
└─ LPs found → SEGMENATION

SEGMENATION
├─ Some objects fail? → skip them
├─ All failed? → skip send
└─ Else → continue to CHECK_FPGA

CHECK_FPGA
├─ IDLE → SEND_IMAGE
├─ WAIT_TX → RECEIVE_RESULT
├─ WAIT_ACK → SEND_ACK
└─ ERROR_XXX → use FPGA ERROR TREE (see below)

RECEIVE_RESULT
├─ Failed? → CHECK_FPGA
└─ OK → POSTPROCESS

POSTPROCESS
└─ Done → SEND_ACK

SEND_ACK
└─ Back to SEND_IMAGE or FRAME_CAPTURE

HALT
└─ Cleanup, stop

ERROR
└─ Log all state, halt system, flush logs
```

---

## 📦 5. FPGA FSM Error Recovery Trees

### 🔄 `ERROR_RX`

```
1. Reset FPGA + reinit
2. If repeated → clear buffer + retry
3. If repeated again → enter ERROR
```

## 📤 `ERROR_TX`

```
1. Reset FPGA + reinit
2. If repeated → clear buffer + retry
3. If repeated again → enter ERROR
```

### 🔌 `ERROR_COM`

```
1. Reset FPGA + reinit
2. If repeated → enter ERROR
```


### 📦 `ERROR_OVERFLOW`

```
1. Split bank, resend
2. If repeated → reset FPGA, resend
3. If repeated again → enter ERROR
```

### ⚠️ `OFFLINE`

```
1. Attempt init
2. If repeated max times → enter ERROR
3. Else → retry
```

### 🌀 `UNKNOWN_STUCK_STATE`

```
1. Reset FPGA if stuck too long
2. If already tried reset → enter ERROR
```


---

## ✅ Summary

- Tiered fallback for all recoverable faults  
- FPGA-aware handling with real-time auto-detection  
- Only enters `ERROR` after multiple failed recovery attempts  
- Ensures system does not silently fail or crash  
- All transitions are logged for traceability


