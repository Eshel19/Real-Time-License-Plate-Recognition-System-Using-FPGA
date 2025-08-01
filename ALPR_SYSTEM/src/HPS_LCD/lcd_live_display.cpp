﻿#include "lcd_live_display.h"

extern "C" {
#include "LCD_Lib.h"
#include "font.h"
#include "LCD_Hw.h"
}

#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define HW_REGS_BASE 0xFC000000
#define HW_REGS_SPAN 0x04000000
LcdLiveDisplay::LcdLiveDisplay() {}
LcdLiveDisplay::~LcdLiveDisplay() {
    if (canvas.pFrame) {
        free(canvas.pFrame);
        canvas.pFrame = nullptr;  
    }

    if (virtual_base && virtual_base != MAP_FAILED) {
        munmap(virtual_base, HW_REGS_SPAN);
        virtual_base = nullptr;  
    }
}

LcdLiveDisplay::operator bool() const {
    return (virtual_base && canvas.pFrame);
}
bool LcdLiveDisplay::init() {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd == -1) {
        perror("open /dev/mem");
        return false;
    }

    virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, HW_REGS_BASE);
    close(fd);

    if (virtual_base == MAP_FAILED) {
        perror("mmap failed");
        virtual_base = nullptr;
        return false;
    }

    LCDHW_Init(virtual_base);
    LCDHW_BackLight(true);
    LCD_Init();

    canvas.Width = LCD_WIDTH;
    canvas.Height = LCD_HEIGHT;
    canvas.BitPerPixel = 1;
    canvas.FrameSize = canvas.Width * canvas.Height / 8;
    canvas.pFrame = (uint8_t*)malloc(canvas.FrameSize);

    if (!canvas.pFrame) {
        munmap(virtual_base, HW_REGS_SPAN);
        virtual_base = nullptr;
        fprintf(stderr, "LCD init failed: malloc failed\n");
        return false;
    }

    snprintf(line0, sizeof(line0), "LP: --------");
    snprintf(line1, sizeof(line1), "FPS: 0.0 E:000");
    snprintf(line2, sizeof(line2), "Offline");
    snprintf(line3, sizeof(line3), "Detected: 0");

    initialized = true;
    refresh();
    return true;
}


void LcdLiveDisplay::init_lcd() {
    LCDHW_Init(virtual_base);
    LCDHW_BackLight(true);
    LCD_Init();

    canvas.Width = LCD_WIDTH;
    canvas.Height = LCD_HEIGHT;
    canvas.BitPerPixel = 1;
    canvas.FrameSize = canvas.Width * canvas.Height / 8;
    canvas.pFrame = (uint8_t*)malloc(canvas.FrameSize);


    if (!canvas.pFrame) {
        fprintf(stderr, "Failed to allocate LCD frame buffer\n");
        return;
    }

    DRAW_Clear(&canvas, LCD_WHITE);
}

void LcdLiveDisplay::refresh() {
    if (!canvas.pFrame) return;

    DRAW_Clear(&canvas, LCD_WHITE);
    DRAW_PrintString(&canvas, 0, 0, line0, LCD_BLACK, &font_16x16);
    DRAW_PrintString(&canvas, 0, 16, line1, LCD_BLACK, &font_16x16);
    DRAW_PrintString(&canvas, 0, 32, line2, LCD_BLACK, &font_16x16);
    DRAW_PrintString(&canvas, 0, 48, line3, LCD_BLACK, &font_16x16);
    DRAW_Refresh(&canvas);
}

void LcdLiveDisplay::format_count(uint32_t count, char* out, int out_size) {
    if (count >= 1000000)
        snprintf(out, out_size, "%.1fM", count / 1000000.0);
    else if (count >= 1000)
        snprintf(out, out_size, "%.1fK", count / 1000.0);
    else
        snprintf(out, out_size, "%u", count);
}

void LcdLiveDisplay::update(
    const std::string& lp_text,
    float fps,
    uint32_t total_lp_count,
    uint32_t error_count,
    uint32_t status_duration_seconds,
    LcdStatus status
    
) {
    if (!virtual_base || !canvas.pFrame) return;

    char tl_str[8];
    format_count(total_lp_count, tl_str, sizeof(tl_str));

    snprintf(line0, sizeof(line0), "LP: %-8s", lp_text.c_str());
    snprintf(line1, sizeof(line1), "FPS:%4.1f E:%03u", fps, error_count);

    const char* status_str = "";
    switch (status) {
    case LcdStatus::Running:  status_str = "Running"; break;
    case LcdStatus::Paused:   status_str = "Paused";  break;
    case LcdStatus::Error:    status_str = "Error";   break;
    case LcdStatus::Offline:  status_str = "Offline"; break;
    }

    if (status == LcdStatus::Offline) {
        snprintf(line2, sizeof(line2), "Offline");
    }
    else {
        int hh = static_cast<int>(status_duration_seconds / 3600);
        int mm = static_cast<int>((status_duration_seconds % 3600) / 60);
        int ss = static_cast<int>(status_duration_seconds % 60);
        snprintf(line2, sizeof(line2), "%-8s%02d:%02d:%02d", status_str, hh, mm, ss);
    }

    snprintf(line3, sizeof(line3), "Detected: %s", tl_str);

    refresh();
}

