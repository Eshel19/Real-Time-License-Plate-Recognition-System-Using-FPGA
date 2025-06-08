# FPGA_HPS_Bridge_AHIM Protocol

## Overview

The FPGA_HPS_Bridge_AHIM protocol defines a robust, high-performance communication interface between a host CPU (HPS) and a custom FPGA-based CNN OCR accelerator via memory-mapped registers and 128-bit wide PIOs, managed by the Accelerator Hot Interface Manager (AHIM).

The protocol is implemented in two layers:
- **Software Layer:** (C++ APIs: low-level & high-level) manages memory-mapped access, command/response, and image data streaming.
- **Hardware Layer:** (FPGA, SystemVerilog) manages command decoding, image/result buffering, FSM-based operation, error handling, and accelerator control.

---

## 1. Register Map (Address Space)

See also: [`software/include/fpga_pio_address.hpp`](../../software/include/fpga_pio_address.hpp)

| Name      | Address Offset | Width  | Direction | Description                        |
|-----------|---------------|--------|-----------|------------------------------------|
| PIO_OUT   | 0x40          | 128b   | HPS→FPGA  | Image data, breakpoints, bursts IN |
| PIO_IN    | 0x00          | 128b   | FPGA→HPS  | Results, header, bursts OUT        |
| PIO_STATUS| 0x20          | 32b    | FPGA→HPS  | Status/flags/IRQ/counters          |
| PIO_CMD   | 0x00          | 32b    | HPS→FPGA  | Commands (reset, upload, etc.)     |

Base physical addresses defined in `fpga_pio_address.hpp`  
- `BRIDGE_BASE` for 128b data, `LW_BRIDGE_BASE` for commands/status

---

## 2. Command Format

### Command Encoding (One-Hot Style)

Commands sent via `PIO_CMD` use **one-hot encoding** for the opcode (top 4 bits), with all other bits as payload or reserved.

| Command Name | Opcode (bits 31:28) | Example Value | Description                                                                 |
|--------------|---------------------|--------------|-----------------------------------------------------------------------------|
| INIT         | 0b0001              | 0x10000000   | Initialize/configure system (startup or after RESET)                        |
| UPLOAD       | 0b0010              | 0x20000000   | Signal start of new image strip transfer                                    |
| ACK_IRQ      | 0b0100              | 0x40000000   | Acknowledge FPGA result, return to idle                                     |
| RESET        | 0b1000              | 0x80000000   | Reset system, enter OFFLINE, requires re-init                               |

*Only one opcode bit can be set at a time (“one-hot” coding).*

---

#### Example: INIT Command Payload
```
[27:24] = max_digits // 4 bits: maximum digits for valid license plate detection
[23:20] = min_digits // 4 bits: minimum digits for valid license plate detection
[19:12] = watchdog_pio // 8 bits: PIO watchdog timeout value (see below)
[11:4] = watchdog_ocr // 8 bits: OCR accelerator watchdog timeout value (see below)
[3] = ocr_break // 1 bit: OCR watchdog behavior control (see below)
[2] = ignore_invalid_cmd// 1 bit: Ignore invalid command (see below)
[1:0] = reserved // 2 bits
```

**Field Explanations:**

- **[31:28] (Opcode) — Always `0x0` for INIT**  
  *This field selects the INIT command, and is not considered part of the payload.*

- **[27:24] (max_digits)**  
  Sets the **maximum number of digits** for a detected license plate.  
  - If the value is invalid or out of range, the FPGA defaults to `10`.

- **[23:20] (min_digits)**  
  Sets the **minimum number of digits** for a detected license plate.  
  - If the value is invalid or out of range, the FPGA defaults to `1`.

- **[19:12] (watchdog_pio)**  
  **PIO Watchdog Timeout** (8 bits).  
  - The actual timeout is: `watchdog_pio << 8` (value × 256).
  - Used to set the number of cycles before a PIO transfer is considered stuck.

- **[11:4] (watchdog_ocr)**  
  **OCR Accelerator Watchdog Timeout** (8 bits).  
  - The actual timeout is: `watchdog_ocr << 12` (value × 4096).
  - Sets the number of cycles before the CNN accelerator is considered hung.

- **[3] (ocr_break)**  
  - If `1`: When the OCR watchdog triggers, the FPGA **halts** in `ERROR_OCR` until reset.
  - If `0`: When the OCR watchdog triggers, the FPGA **skips the current plate** and moves on to the next.

- **[2] (ignore_invalid_cmd)**  
  - If `1`: **Invalid or out-of-sequence commands are ignored**; the FPGA continues operation.
  - If `0`: Invalid commands trigger an error (`ERROR_COM`) and halt operation until reset.

---

**Note:**  
All multi-bit fields are unsigned.  
This command lets you **dynamically adjust system runtime behavior and robustness** without rebuilding hardware or software.

---

#### Example: UPLOAD Command Payload

The **UPLOAD** command prepares the FPGA to receive a new strip image (potentially containing multiple LP sub-images).  
The remaining bits encode key transfer parameters:

```
[27:12] = total_strip_length (16b) - Total width in columns of the concatenated strip containing all LP sub-images.
[11:4] = image_count (8b) - Number of LP sub-images in the strip (e.g., 1 for a single plate, 20 for a batch).
[3:0] = reserved

```

**Field Explanations:**
- **[27:12] total_strip_length (16 bits)**  
  The combined width (in columns) of all images to be sent as a single strip to the FPGA.
- **[11:4] image_count (8 bits)**  
  The number of distinct LP images/sub-images in this strip.
- **[3:0] reserved**  
  Must be zero.

---

### Example: Sending an UPLOAD Command

- To upload a strip of **5 images** with **total width 80 columns**:
  - Opcode: `0b0010` (`UPLOAD` → bit 29 high)
  - Payload: `total_strip_length=80`, `image_count=5`
  - Command word: `0x200A0140`
    - `[31:28]=0b0010`, `[27:12]=0x0050` (80), `[11:4]=0x05`, `[3:0]=0x0`

---

**This section now matches your one-hot encoding and protocol philosophy, and is ready for your documentation!**  
If you want similar breakdowns for other commands (INIT, RESET, ACK_IRQ) with example hex values, let me know.


---

## 3. Data Transfer Protocol

### Sending Images

1. **Send UPLOAD Command:**  
   Specify number of images and total columns.
2. **Send Breakpoints:**  
   Array of `uint16_t` values (final column of each image). Sent as 128-bit (8 x uint16) bursts via PIO_OUT.
3. **Send Image Data:**  
   Flattened INT8, column-major, 16 rows per column. Each 128b word: 16 bytes (row 0=top, row 15=bottom).

### Receiving Results

1. **Wait for `result_ready` flag in STATUS.**
2. **Read 16-byte Header:**  
   - Byte 0: result word count (`n`)
   - Bytes 1-15: reserved
3. **Read `n` Result Words:**  
   Each is 16 bytes, ASCII, packed with null (`\0`) delimiters for string separation.
4. **Parse Results:**  
   Split bytes on `\0` for individual results (e.g., license plate strings).

---

## 4. Status Register (`PIO_STATUS`)

| Bit(s)  | Name               | Description                                 |
|---------|--------------------|---------------------------------------------|
| 0       | pio_out_ready      | 1 = Ready for new OUT data                  |
| 1       | pio_in_valid       | 1 = IN data valid for read                  |
| 2       | busy/irq_active    | Accelerator busy / IRQ                      |
| 3       | result_ready       | OCR result available                        |
| 4       | error_flag         | Error detected (command, overflow, etc.)    |
| 9:6     | fsm_state          | 4-bit FSM state (see decode table)          |
| 17:10   | images_processed   | Counter (wraps at 255)                      |
| 25:18   | images_with_digits | Counter (wraps at 255)                      |
| 31:26   | reserved           | —                                           |

---

## 5. Error Handling & Recovery

- **Invalid Sequence:**  
  Out-of-order or malformed commands trigger `error_flag` and set FSM to `ERROR_*` state. Further processing blocked until a RESET command.
- **API-level Protection:**  
  Software API blocks unsafe/illegal ops unless `unsafe_mode` is enabled.
- **Recovery:**  
  Send RESET (`0b1000`) command. Status/counters clear, FSM returns to `OFFLINE`.

---

## 6. FSM AHIM State Table

| Value | State Name        | Meaning                                                              |
|-------|-------------------|----------------------------------------------------------------------|
| 0     | OFFLINE           | System reset, waiting for INIT                                       |
| 1     | IDLE              | Ready to recieve UPLOAD CMD                                          |
| 2     | ACK_BP            | Awaiting breakpoints                                                 |
| 3     | ACK_STRIP         | Awaiting image strip                                                 |
| 4     | PROCESS_IMAGE     | OCR processing in progress                                           |
| 5     | NEXT_IMAGE        | AHIM sending next image's start and end address                      |
| 6     | NEXT_IMAGE_VALID  | OCR valid result, AHIM sending next image's start and end address    |
| 7     | WAIT_POST_RX      | Waiting for final result to be loaded to RAM                         |
| 8     | WAIT_RAM_STORED   | Delay to allow the result to be fully stored in RAM                  |
| 9     | WAIT_TX           | Result ready to be sent                                              |
| 10    | WAIT_ACK          | Waiting for user/program to acknowledge result                       |
| 11    | ERROR_RX          | Error in receiving data (watchdog has been triggered)                |
| 12    | ERROR_TX          | Error in transmitting data (watchdog has been triggered)             |
| 13    | ERROR_COM         | Protocol/command error                                               |
| 14    | ERROR_OCR         | Accelerator (CNN) error (watchdog has been triggered)                |
| 15    | ERROR_OVERFLOW    | Buffer/strip overflow                                                |


*(See: `default_fsm_decode` in software for the full table)*

---

## 7. Timing & Throughput

- **128-bit bursts** enable high-throughput transfers (images, breakpoints, results).
- **Status flags** ensure safe handshaking for both sides.
- **Typical latency:** 2–3ms per image (batch mode supported).

---

## 8. Work flow Command Flow

1. Send INIT command (configure system) only at start up or after reset
2. Send UPLOAD command (number of images, strip length)
3. Send breakpoints (as 128b burst(s)) the end point location of each sub image within the strip
4. Send image data (as 128b burst per column) 
5. Wait for WAIT_ACK or WAIT_TX STATUS
    -if WAIT_TX:
        5.1 Read result header (first 8 byts) tell the CPU how many packange he is going to read from the FPGA 
        5.2 Read result bursts (as indicated by header)
6. Send ACK_IRQ command to set the AHIM system back to idle state we go back to step 2
7. If error_flag is set, or FSM is in ERROR_* state, send RESET and re-initialize with INIT.
