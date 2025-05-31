#pragma once
// Config.h
#pragma once

#include <string>
#include <unordered_map>

class Config {
public:
    // Load the config file from a given path (e.g. /etc/alpr_system/config.ini)
    bool loadFromFile(const std::string& path);

    // Retrieve string, integer, and boolean values with optional defaults
    std::string getString(const std::string& key, const std::string& def = "") const;
    int getInt(const std::string& key, int def = 0) const;
    bool getBool(const std::string& key, bool def = false) const;

    // Print all config entries (used in debug/deep mode)
    void print() const;

private:
    std::unordered_map<std::string, std::string> entries_;
};
