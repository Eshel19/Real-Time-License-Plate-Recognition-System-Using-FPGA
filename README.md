# Real-Time License Plate Recognition System Using FPGA

## Introduction

This repository contains the complete code and documentation for my final-year project: **Real-Time License Plate Recognition System Using FPGA**. The aim of this project is to develop a high-performance, real-time license plate recognition (LPR) system, leveraging advanced CPU image processing and custom hardware acceleration on an FPGA platform. The result is a robust, modular pipeline that achieves fast, accurate LPR beyond what is possible with CPU-only systems.

---

## Features

- **Real-Time Proccessing:** Achieves an average preprocessing time of **34ms** per image **(detection + segmentation)**, and end-to-end system throughput of **15–17 FPS** for the full pipeline.
- **Detection Accuracy:** The plate detection and segmentation stage achieves 86% accuracy in real-world test conditions.
- **FPGA Acceleration:** Utilizes VHDL/SystemVerilog on a DE10 Standard FPGA board for CNN-based OCR.
- **Advanced Image Preprocessing:** Implemented in C++ with the NanoDet object detection model and custom segmentation techniques.
- **Flexible CPU-FPGA Bridge/API:** C++ communication library for high-speed, robust CPU-to-FPGA data/control transfer.
- **Custom Linux Platform:** Kernel, U-Boot, and device tree tailored for the FPGA system, with full build scripts and documentation.
- **End-to-End Documentation:** Clear system diagrams, workflow charts, and performance results.

---

*Curious about the engineering journey behind this project?  
See [The Full Project Story](docs/full_story.md) in the docs folder.*

---

## Project Structure

- **ALPR_SYSTEM/** – Full pipeline runtime: coordinates preprocessing, FPGA bridge, watchdogs, FSM, logging.
- **alprcrtl/** – CLI tool to control and monitor the ALPR system.
- **CPU_preprocessing/** – Plate detection/segmentation code (C++/Python), notebooks, benchmarks.
- **FPGA_HPS_Bridge_AHIM/** – Bridge submodule for CPU–FPGA comms.  
  Contains `hardware/` (HDL), `software/` (API), and `docs/` (protocol/diagrams).  
  *See its README for details.*
- **FPGA_OCR_CNN/** – Quantized CNN OCR IP core (HDL, quantization, memory files).
- **LINUX_config_files/** – Kernel, device tree, and boot scripts for the platform.
- **docs/** – High-level project docs, diagrams, final reports.

*Each main submodule or major folder contains its own `README.md` with specific usage, build, and integration instructions.*



### Folder Descriptions

- **ALPR_SYSTEM/**  
  C++ COde for full integrated runtime for the ALPR pipeline. Handles FSM coordination, preprocessing, watchdog, FPGA communication, OCR triggering, and logging. Designed to run continuously and autonomously under embedded Linux.

- **alprcrtl/**  
  Command-line controller for managing and interacting with the ALPR_SYSTEM. Sends control commands, initiates single-frame capture or live runs, monitors state/status, and supports system testing/debug.

- **CPU_preprocessing/**  
  C++ and Python code for real-time license plate detection and segmentation. Includes object detection (NanoDet), segmentation routines, benchmark/test scripts, and Jupyter notebooks for experiments.

- **FPGA_HPS_Bridge_AHIM/**  
  Standalone bridge module (submodule):  
    - `/hardware`: HDL (SystemVerilog/VHDL) for AHIM, RX/TX, FSM, and memory.
    - `/software`: C++/Python API for CPU–FPGA comms.
    - `/docs`: Full protocol, diagrams, block charts.
    - `readme.md`: Mini-overview, build/test instructions.

- **FPGA_OCR_CNN/**  
  FPGA implementation of a quantized CNN for optical character recognition, including memory initialization files, quantization scripts, and HDL for CNN logic.  
  *(This is a copy or submodule of [CNN_FPGA_OCR](https://github.com/Eshel19/CNN_FPGA_OCR))*

- **LINUX_config_files/**  
  Kernel and U-Boot configs, device tree sources, and all scripts/files for building and configuring the custom Linux environment needed for the DE10 Standard board.

- **docs/**  
  Full documentation, system diagrams, workflow charts, build notes, and additional resources.

---

## How to Use

The code in this repository is provided for educational and demonstration purposes. To explore or reproduce the project:

1. **Image Preprocessing & Detection:**  
   - See `/CPU_preprocessing/` for C++/Python code and notebooks.  
   - Run detection and segmentation to extract plates and prepare images for FPGA OCR.

2. **CPU–FPGA Communication:**  
   - `/FPGA_HPS_Bridge_AHIM/software/` provides API/library to send images and commands to the FPGA, and receive results.
   - Follow subfolder README for example usage.

3. **FPGA Hardware Build:**  
   - Synthesize and deploy `/FPGA_HPS_Bridge_AHIM/hardware/` (bridge) and `/FPGA_OCR_CNN/` (CNN core) HDL on the DE10 board.
   - Each submodule has build and simulation instructions.

4. **Linux Platform Setup:**  
   - `/LINUX_config_files/` contains all necessary files and build scripts for a custom Linux/U-Boot/device tree environment, fully compatible with the DE10 Standard FPGA board.

5. **Integrated ALPR Runtime System:**  
   - To run the full autonomous ALPR system, see `/ALPR_SYSTEM/`.  
   - This contains the real-time FSM, FPGA bridge logic, watchdog, result parsing, logging, and full operational flow.  
   - The system is designed for continuous deployment and has been tested with 100+ hour runtime stability.

6. **System Control Interface:**  
   - `/alprcrtl/` provides a simple command-line control program to manage, debug, or trigger OCR operations from the CPU.  
   - Supports status monitoring, controlled runs, and system resets.

7. **Documentation:**  
   - `/docs/` contains detailed explanations, block diagrams, architecture charts, and reports that provide a deep dive into the system’s development and integration.

> **Note:**  
> Reproducing the complete system requires the Terasic DE10 Standard FPGA board and a compatible embedded Linux setup.  

---

## Building the Custom Linux Distribution

To create the custom Linux distribution for the DE10 Standard FPGA board, I followed the guide by [Zangman De10-nano](https://github.com/zangman/de10-nano) and Altera’s open-source code:

- Setting up the cross-compilation environment
- Building the U-Boot bootloader
- Compiling the Linux kernel with required configuration
- Creating the root filesystem
- Integrating necessary libraries (OpenCV, etc.)
- Compling NCNN 

---

## Demonstrations

### Overview Architecture

![Overview Architecture](docs/images/project%20Diagram.drawio.png)  
*Figure 1: Overview architecture of the Real-Time License Plate Recognition System.*

### License Plate Detection Example

![License Plate Detection](docs/images/detection_example.png)  
*Figure 2: Result of the license plate detection algorithm on a sample image.*

### License Plate Preprocessing Workflow

![License Plate preprocessing workflow](docs/images/preprocessing_workflow.jpg)  
*Figure 3: Overview of the preprocessing workflow.*

### AI OCR Accelerator – Top-Level Architecture

![AI OCR Accelerator Top View](FPGA_OCR_CNN/architecture/ocr_architecture_overview.png)  
*Figure 4: High-level architecture of the FPGA-based CNN OCR Accelerator. Designed for INT8 inference, programmable thresholding, and modular convolutional + fully connected structure.*

### Accelerator Host Interface Manager (AHIM)

![AHIM Top View](FPGA_HPS_Bridge_AHIM\hardware\architecture\Bridge_high_level.drawio.png)  
*Figure 5: AHIM block diagram showing the internal structure of the CPU-FPGA bridge. Manages synchronization, watchdogs, command handling, and data routing between HPS and OCR core.*

### Live System Runtime (103+ Hours)

![System Runtime](ALPR_SYSTEM/docs/images/100H_runtime.jpg)  
*Figure 6: Live LCD display showing system uptime of over 103 hours with stable FPS and no errors. This confirms long-term robustness and real-time operation of the ALPR pipeline on FPGA.*

---

## Project Status

- ✅ **System Completed and Operational:**
  - The full real-time ALPR system is now integrated, running autonomously on embedded Linux + FPGA.
  - End-to-end pipeline includes image preprocessing, CNN-based OCR accelerator, and a fully pipelined CPU–FPGA communication protocol.
  - System tested for **100+ hours of continuous operation** with **0 crashes** and stable performance at ~16 FPS.
  - OCR inference runs on FPGA in ~870 µs per full plate.
  - Watchdog, logging, control interface (`alprcrtl`), and LCD display are all active and validated.

- 🧪 **Current Focus:**
  - Ongoing **optimization** for performance tuning and resource usage.
  - Continued improvement of **digit segmentation and accuracy** via dataset expansion.
  - Finalizing **documentation**, **GitHub cleanup**, and full source release instructions.

---

## References

1. Terasic DE10-Standard: [Terasic DE10-Standard](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1081)
2. Nanodet: [Nanodet](https://github.com/RangiLyu/nanodet)
3. Ncnn: [Ncnn](https://github.com/Tencent/ncnn)
4. Zangman De10-nano: [Zangman De10-nano](https://github.com/zangman/de10-nano)
5. Altera-opensource u-boot: [Altera-opensource u-boot](https://github.com/altera-opensource/u-boot-socfpga)
6. Altera-opensource linux-Kernel: [Altera-opensource linux-Kernel](https://github.com/altera-opensource/linux-socfpga)
7. Arch linux pre-built rootfs: [Arch linux pre-built rootfs](https://fl.us.mirror.archlinuxarm.org/os/)
8. License Plates Dataset by objectdetection: [License Plates Recognition Dataset](https://www.kaggle.com/objectdetection/license-plates-recognition-dataset)
9. License Plates Dataset by N N: [islipl3 Dataset](https://www.kaggle.com/nn/islipl3-dataset)
10. Israel License Plates Dataset by Gael Cohen: [license_plate_israel](https://www.kaggle.com/gaelcohen/license-plate-israel)
11. License Plates Dataset by SCH: [plate Dataset](https://www.kaggle.com/sch/plate-dataset)

---

## Acknowledgments

- **Supervisor:** Dr. Binyamin Abramov, for his invaluable guidance and support throughout this project.
- **Afeka College:** For providing resources and facilities.
- **Open-Source Community:** Developers of NanoDet, OpenCV, and other tools used in this project.

---

For full build instructions, see the README files within each subfolder and the docs directory.  
For questions, contact [Eshel Epstein](eshel19@gmail.com) or open an issue.

---
