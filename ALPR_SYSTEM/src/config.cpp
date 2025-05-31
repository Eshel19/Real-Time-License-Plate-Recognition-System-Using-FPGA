// Config.cpp
#include "config.hpp"
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>

bool Config::loadFromFile(const std::string& path) {
    std::ifstream file(path);
    if (!file.is_open()) return false;

    std::string line;
    while (std::getline(file, line)) {
        auto comment = line.find('#');
        if (comment != std::string::npos)
            line = line.substr(0, comment);

        auto delimiter = line.find('=');
        if (delimiter == std::string::npos) continue;

        std::string key = line.substr(0, delimiter);
        std::string val = line.substr(delimiter + 1);

        key.erase(0, key.find_first_not_of(" \t\r\n"));
        key.erase(key.find_last_not_of(" \t\r\n") + 1);
        val.erase(0, val.find_first_not_of(" \t\r\n"));
        val.erase(val.find_last_not_of(" \t\r\n") + 1);

        if (!key.empty())
            entries_[key] = val;
    }
    return true;
}

std::string Config::getString(const std::string& key, const std::string& def) const {
    auto it = entries_.find(key);
    return it != entries_.end() ? it->second : def;
}

int Config::getInt(const std::string& key, int def) const {
    auto it = entries_.find(key);
    if (it != entries_.end()) {
        try { return std::stoi(it->second); }
        catch (...) {}
    }
    return def;
}

bool Config::getBool(const std::string& key, bool def) const {
    auto it = entries_.find(key);
    if (it != entries_.end()) {
        std::string val = it->second;
        std::transform(val.begin(), val.end(), val.begin(), ::tolower);
        return val == "1" || val == "true" || val == "yes";
    }
    return def;
}

void Config::print() const {
    for (const auto& kv : entries_)
        std::cout << kv.first << " = " << kv.second << "\n";
}
