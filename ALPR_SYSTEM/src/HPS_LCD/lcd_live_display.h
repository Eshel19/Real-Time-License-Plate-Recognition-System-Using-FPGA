#ifndef LCD_LIVE_DISPLAY_H
#define LCD_LIVE_DISPLAY_H

#include <cstdint>
#include <string>

// Forward declare
extern "C" {
#include "lcd_graphic.h"
}

class LcdLiveDisplay {
public:
    bool init();
    LcdLiveDisplay();
    ~LcdLiveDisplay();

    enum class LcdStatus {
        Running,
        Paused,
        Offline,
        Error
    };

    void update(
        const std::string& lp_text,
        float fps,
        float avg_lp_time_ms,
        uint32_t frame_lp_count,
        uint32_t total_lp_count,
        uint32_t error_count,
        LcdStatus status
    );
    explicit operator bool() const;
private:
    void* virtual_base = nullptr;
    LCD_CANVAS canvas{};
    bool initialized = false;
    char line0[17], line1[17], line2[17], line3[17];

    void init_lcd();
    void refresh();
    void format_count(uint32_t count, char* out, int out_size);
};

#endif // LCD_LIVE_DISPLAY_H
