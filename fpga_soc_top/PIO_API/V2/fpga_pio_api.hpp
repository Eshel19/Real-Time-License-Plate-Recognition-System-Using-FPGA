// fpga_pio_api.hpp — Header‑only C++17 helper for Cyclone‑V/HPS ⇄ FPGA **128‑bit** PIO
// -----------------------------------------------------------------------------
// ▸ Uses the Quartus‑generated address header (`hps_0.h` or `soc_system.h`).
// ▸ Assumes your custom Avalon‑MM PIO slaves expose a **full 128‑bit data bus**
//   on a single address (no 4 × 32‑bit lanes). Each push/pop is therefore a
//   single `strd q` (NEON) on Cortex‑A9.
// ▸ Works in userspace via `/dev/mem`; no other libs.
// ▸ Generic helpers to sling arbitrary POD buffers through the FIFO, with
//   timeout‑bound blocking.
// -----------------------------------------------------------------------------
// 2025‑05‑05 — rev‑2 (adapt to true 128‑bit slave width).
// -----------------------------------------------------------------------------
#pragma once

#include <cstdint>
#include <cstddef>
#include <span>
#include <vector>
#include <system_error>
#include <chrono>
#include <cstring>
#include <functional>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

using namespace std::chrono_literals;   // enables 100ms literal

// ───────────────────────────────── bring in base macros ────────────────────
#if __has_include("hps_0.h")
  #include "hps_0.h"
#elif __has_include("soc_system.h")
  #include "soc_system.h"
#endif
#ifndef PIO128_OUT_0_BASE
  #define PIO128_OUT_0_BASE 0xC0000010u
#endif
#ifndef PIO128_IN_WITH_FIFO_0_BASE
  #define PIO128_IN_WITH_FIFO_0_BASE 0xC0000000u
#endif
#ifndef PIO_COMMAND_BASE
  #define PIO_COMMAND_BASE 0xFF200000u
#endif

namespace fpga {

// ─────────────────────────── /dev/mem RAII mapper ─────────────────────────
class MemRegion {
 public:
  MemRegion(std::uintptr_t phys, std::size_t span = 0x1000) {
    fd_ = ::open("/dev/mem", O_RDWR | O_SYNC);
    if (fd_ < 0) throw std::system_error(errno, std::generic_category(),
                                         "open /dev/mem");
    off_t page = phys & ~(off_t)0xFFF;
    off_t delta = phys & 0xFFF;
    span_ = span + delta;
    map_ = ::mmap(nullptr, span_, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, page);
    if (map_ == MAP_FAILED) {
      ::close(fd_);
      throw std::system_error(errno, std::generic_category(), "mmap");
    }
    virt_ = static_cast<std::uint8_t*>(map_) + delta;
  }
  ~MemRegion() {
    if (map_ && map_ != MAP_FAILED) ::munmap(map_, span_);
    if (fd_ >= 0) ::close(fd_);
  }
  template<typename T>
  inline T read(std::size_t off = 0) const noexcept {
    return *reinterpret_cast<volatile T*>(virt_ + off);
  }
  template<typename T>
  inline void write(T v, std::size_t off = 0) const noexcept {
    *reinterpret_cast<volatile T*>(virt_ + off) = v;
  }
  inline volatile __uint128_t* ptr128(std::size_t off = 0) const noexcept {
    return reinterpret_cast<volatile __uint128_t*>(virt_ + off);
  }
 private:
  void* map_{nullptr};
  std::size_t span_{0};
  int  fd_{-1};
  std::uint8_t* virt_{nullptr};
};

// ───────────────────────── spin helper (busy‑wait) ─────────────────────────
inline bool spin_until(const std::function<bool()>& ready,
                       std::chrono::milliseconds tmo) {
  auto end = std::chrono::steady_clock::now() + tmo;
  while (!ready()) {
    if (std::chrono::steady_clock::now() >= end) return false;
  }
  return true;
}

// ─────────────────────── 128‑bit pack/unpack helpers ───────────────────────
namespace detail {
inline void pack_le128(std::uint8_t* dst, const std::byte* src, std::size_t n) {
  std::memset(dst, 0, 16);
  std::memcpy(dst, src, n);
}
inline void unpack_le128(std::byte* dst, const std::uint8_t* src, std::size_t n) {
  std::memcpy(dst, src, n);
}
}  // namespace detail

// ───────────────────────────── PIO 128‑bit OUT ─────────────────────────────
class Pio128Out {
 public:
  Pio128Out() : reg_(PIO128_OUT_0_BASE) {}

  inline void push(__uint128_t v) const noexcept {
    *reg_.ptr128() = v;   // single 128‑bit store
  }

  std::error_code write(std::span<const std::byte> buf,
                        std::chrono::milliseconds tmo = 100ms) const {
    const std::byte* p = buf.data();
    std::size_t n = buf.size();
    alignas(16) std::uint8_t tmp[16];

    while (n) {
      std::size_t chunk = n < 16 ? n : 16;
      detail::pack_le128(tmp, p, chunk);
      if (!spin_until([]{ return true; }, tmo))  // TODO: poll FIFO status reg
        return std::make_error_code(std::errc::timed_out);
      push(*reinterpret_cast<__uint128_t*>(tmp));
      p += chunk;
      n -= chunk;
    }
    return {};
  }
 private:
  MemRegion reg_;
};

// ───────────────────────────── PIO 128‑bit IN ──────────────────────────────
class Pio128In {
 public:
  Pio128In() : reg_(PIO128_IN_WITH_FIFO_0_BASE) {}

  inline __uint128_t pop() const noexcept {
    return *reg_.ptr128();
  }

  std::error_code read(std::span<std::byte> dst,
                       std::chrono::milliseconds tmo = 100ms) const {
    std::byte* p = dst.data();
    std::size_t n = dst.size();
    alignas(16) std::uint8_t tmp[16];

    while (n) {
      if (!spin_until([]{ return true; }, tmo))  // TODO: poll FIFO status reg
        return std::make_error_code(std::errc::timed_out);
      __uint128_t w = pop();
      std::memcpy(tmp, &w, 16);
      std::size_t chunk = n < 16 ? n : 16;
      detail::unpack_le128(p, tmp, chunk);
      p += chunk;
      n -= chunk;
    }
    return {};
  }
 private:
  MemRegion reg_;
};

// ────────────────────────────── 32‑bit CMD PIO ─────────────────────────────
class PioCmd32 {
 public:
  PioCmd32() : reg_(PIO_COMMAND_BASE) {}
  inline void write(std::uint32_t v) const noexcept { reg_.write<std::uint32_t>(v); }
  inline std::uint32_t read() const noexcept { return reg_.read<std::uint32_t>(); }
 private:
  MemRegion reg_;
};

} // namespace fpga
