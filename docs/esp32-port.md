# ESP32 (Original) + ILI9341 TFT Port

## Goal

Port the physics engine SDL3 desktop app to run on bare-metal **ESP32 (Xtensa LX6)** with a **320×240 ILI9341 SPI TFT displaye**, using **pure Zig** with the **Zig build system driving everything** (no ESP-IDF build system).

**Status**: Research / on hold — deferred until the desktop game is complete.

---

## Toolchain

### Forked Zig (required for Xtensa codegen)

Upstream Zig 0.16.0 **cannot** compile for Xtensa (`compiler backend unavailable`). A fork is needed:

```bash
curl -L -o zig-xtensa.tar.xz \
  https://github.com/kassane/zig-espressif-bootstrap/releases/download/0.16.0-xtensa/zig-relsafe-x86_64-darwin-baseline.tar.xz
tar -xJf zig-xtensa.tar.xz
export PATH="$PWD/zig-relsafe-x86_64-darwin-baseline:$PATH"
```

- Repo: https://github.com/kassane/zig-espressif-bootstrap
- The fork exposes ESP32 chips as custom OS tags (`xtensa-esp32-none`, `xtensa-esp32s2-none`, `xtensa-esp32s3-none`)
- Without this fork, only RISC-V ESP32 variants (C3/C6) can be targeted with upstream Zig

### Other tools

| Tool | Install | Purpose |
|------|---------|---------|
| QEMU (Xtensa) | `brew install qemu` | Test firmware in emulation before flashing |
| esptool.py | `pip install esptool` | Flash `.bin` to ESP32 over UART |
| ESP-IDF (optional) | `~/esp/esp-idf/install.sh esp32` | Reference for linker scripts, register maps, boot process — not required at build time |

---

## Reference implementations

### Pure Zig bare-metal (recommended approach)

**`kassane/esp32-baremetal-zig`** — https://codeberg.org/kassane/esp32-baremetal-zig

Does exactly what we want:
- Pure Zig, no C, no ESP-IDF, no libc
- `build.zig` generates linker scripts at build time via `b.addWriteFiles()`
- Custom reset vector entry point (`Reset`)
- Registers generated from SVD files via an included `svd2zig` tool
- MMIO abstraction + HAL (GPIO, UART, Timer, etc.)
- QEMU support for testing
- Dual output: `.elf` + `.bin` for hardware

Key `build.zig` patterns to borrow:

```zig
const target = b.resolveTargetQuery(.{
    .cpu_arch = .xtensa,
    .os_tag = .{ .custom = "esp32" },  // Espressif fork OS tag
    .abi = .none,
});

const exe = b.addExecutable(.{
    .name = "physics-esp32",
    .root_source_file = b.path("src/esp32/main.zig"),
    .target = target,
    .optimize = .ReleaseSmall,
});
exe.entry = .{ .symbol_name = "Reset" };
exe.bundle_compiler_rt = false;
exe.setLinkerScript(ld_script);

const bin = b.addObjCopy(exe.getEmittedBin(), .{ .format = .bin, .basename = "physics-esp32.bin" });
```

### Zig + ESP-IDF hybrid (alternative)

**`kassane/zig-esp-idf-sample`** — https://github.com/kassane/zig-esp-idf-sample

Uses `build.zig` to compile Zig + wrappers around ESP-IDF C libraries, then CMake/idf.py handles final linking and flashing. More practical but less "pure Zig."

---

## Memory map (ESP32 original)

From `esp32-baremetal-zig`:

| Region | Start | Length | Purpose |
|--------|-------|--------|---------|
| iRAM | `0x40080000` | 128KB | Code that must run from RAM (reset vector, cache init) |
| DRAM | `0x3FFB0000` | ~176KB | Data + BSS |
| iROM (flash) | `0x400D0020` | ~3MB | Code executed from flash cache |
| dROM (flash) | `0x3F400020` | ~4MB | Read-only data from flash cache |

The ILI9341 framebuffer (320×240×2 = 150KB) must fit in DRAM alongside other data. The ESP32 has 520KB total SRAM, so this is tight but feasible.

---

## Linker script

Generated at build time in `build.zig`. Borrowed from `esp32-baremetal-zig`:

```
ENTRY(Reset)
MEMORY {
  iram_seg (RX) : ORIGIN = 0x40080000, LENGTH = 0x20000
  dram_seg (RW) : ORIGIN = 0x3FFB0000, LENGTH = 0x2C200
  irom_seg (RX) : ORIGIN = 0x400D0020, LENGTH = 0x330000 - 0x20
  drom_seg (R)  : ORIGIN = 0x3F400020, LENGTH = 0x400000 - 0x20
}
SECTIONS {
  .text : ALIGN(4) { _stext = .; *(.literal .text .literal.* .text.*) _etext = .; } > irom_seg
  .rodata : ALIGN(4) { _rodata_start = ABSOLUTE(.); *(.rodata .rodata.*) _rodata_end = ABSOLUTE(.); } > drom_seg
  .data : ALIGN(4) { _data_start = ABSOLUTE(.); *(.data .data.*) _data_end = ABSOLUTE(.); } > dram_seg AT > drom_seg
  _sidata = LOADADDR(.data);
  .bss (NOLOAD) : ALIGN(4) { _bss_start = ABSOLUTE(.); *(.bss .bss.* COMMON) _bss_end = ABSOLUTE(.); } > dram_seg
  .rwtext : ALIGN(4) { *(.rwtext .rwtext.* .rwtext.literal .rwtext.literal.*) } > iram_seg
}
```

---

## Project structure

```
src/
  esp32/
    main.zig        # Reset entry point + game loop (export fn Reset() noreturn)
    startup.zig     # Boot: disable WDT, zero BSS, copy .data, enable cache, call Reset
    spi.zig         # ESP32 SPI controller driver (register-level, TRM chapter 8)
    ili9341.zig     # ILI9341 init sequence + command protocol + flush
    display.zig     # Framebuffer (320×240×2 = 150KB) + pixel/rect/text drawing
    gpio.zig        # GPIO output (CS, DC, RST) + button input
    timer.zig       # Cycle counter / timer group for frame timing
    input.zig       # Button state machine
    math.zig        # f32 Vec2 (ESP32 has single-precision FPU — use as-is!)
    schema.zig      # Position/Velocity (copy from src/type_schema.zig)
    physics.zig     # Kinematics (translate2DShape, etc.)
build.zig           # Build pipeline
ld/
    esp32.ld        # Generated at build time via addWriteFiles
```

---

## Startup sequence

1. **Reset vector** — ESP32 jumps to `0x40080000` (entry point `Reset`)
2. **Watchdog disable** — TIMG0/TIMG1 WDT must be disabled or they'll reset the chip
3. **Cache enable** — Configure flash cache so code in iROM/dROM is accessible
4. **BSS zero** — Zero `.bss` section in DRAM
5. **Data copy** — Copy `.data` from flash (dROM) to DRAM
6. **Call main** — Jump to `Reset()` Zig function

Kassane's `src/startup.zig` handles steps 1-6 via inline assembly and MMIO writes.

---

## SPI driver (the hardest part)

ESP32 has 3 SPI controllers. SPI2 (`0x3FF64000`) and SPI3 (`0x3FF65000`) are available for general use.

### Key registers (from TRM Ch. 8)

| Register | Offset | Purpose |
|----------|--------|---------|
| `CMD` | `0x00` | Command register (usr bit to start transaction) |
| `ADDR` | `0x04` | Address phase data |
| `CTRL` | `0x08` | Control (mode, etc.) |
| `CLK` | `0x0C` | Clock divider |
| `USER` | `0x10` | User config (command/addr/mosi/dummy phases) |
| `USER1` | `0x14` | Phase lengths |
| `USER2` | `0x18` | Command value + bit length |
| `MOSI_DLEN` | `0x24` | MOSI data length in bits |
| `MISO_DLEN` | `0x28` | MISO data length in bits |
| `W0–W15` | `0x80–0xBC` | Data buffers (32-bit each) |

### Minimal register access pattern

```zig
const SPI2_BASE = 0x3FF64000;

const SpiRegs = extern struct {
    cmd: u32,            // 0x00
    addr: u32,           // 0x04
    ctrl: u32,           // 0x08
    clk: u32,            // 0x0C
    user: u32,           // 0x10
    user1: u32,          // 0x14
    user2: u32,          // 0x18
    // ... more fields
    w: [16]u32,          // 0x80..0xBC
};

const spi = @as(*volatile SpiRegs, @ptrFromInt(SPI2_BASE));
```

### GPIO matrix

ESP32 has a flexible GPIO matrix. SPI pins aren't fixed — you route them:

```zig
// Route SPI2 signals to physical pins (example: standard ILI9341 wiring)
const GPIO_FUNC = @as(*volatile [40]u32, @ptrFromInt(0x3FF44570));
// GPIO 5  → SPICS0
// GPIO 18 → SPICLK
// GPIO 23 → SPID (MOSI)
// GPIO 19 → SPIQ (MISO)
// GPIO 22 → SPID4 (DC — but use GPIO bitbanging instead)
```

**Alternative (simpler for Phase 1): bitbang SPI via GPIO registers.**

For low-resolution 320×240 at moderate frame rates (15-30fps), bitbanged SPI on an ESP32 at 240MHz is sufficient for a physics demo with a single moving square. Saves weeks of SPI driver development.

```zig
fn spi_bitbang_write(data: u8) void {
    for (0..8) |i| {
        set_mosi((data >> (7 - i)) & 1);
        pulse_sclk();
    }
}
```

---

## ILI9341 driver

### Pin connections (typical)

| Function | GPIO | ILI9341 pin |
|----------|------|-------------|
| CS | 5 | Chip select (active low) |
| RST | 4 | Hardware reset (active low) |
| DC | 2 | Data/Command select |
| MOSI | 23 | Master out, slave in |
| SCLK | 18 | SPI clock |
| MISO | 19 | Master in, slave out (optional) |
| LED | 3.3V | Backlight (or PWM via GPIO) |

### Init sequence (essential commands)

```zig
fn ili9341_init() void {
    gpio_write(RST, 0);
    delay_ms(10);
    gpio_write(RST, 1);
    delay_ms(120);

    write_cmd(0x01);  // Software reset
    delay_ms(120);

    write_cmd(0x11);  // Sleep out
    delay_ms(120);

    write_cmd(0x3A);  // Pixel format
    write_data(0x55); // 16-bit RGB565

    write_cmd(0x36);  // Memory access control
    write_data(0x48); // MADCTL: BGR, rotate

    write_cmd(0x29);  // Display ON
    delay_ms(50);
}
```

### Framebuffer flush

ILI9341 uses column/page addressing to accept pixel data for a rectangular region:

```zig
fn ili9341_set_window(x0: u16, y0: u16, x1: u16, y1: u16) void {
    write_cmd(0x2A);  // Column address set
    write_data(x0 >> 8); write_data(x0 & 0xFF);
    write_data(x1 >> 8); write_data(x1 & 0xFF);

    write_cmd(0x2B);  // Page address set
    write_data(y0 >> 8); write_data(y0 & 0xFF);
    write_data(y1 >> 8); write_data(y1 & 0xFF);

    write_cmd(0x2C);  // Memory write
}

fn flush_framebuffer(fb: []u16) void {
    ili9341_set_window(0, 0, 239, 319);
    for (fb) |pixel| {
        write_data_16(pixel);
    }
}
```

For performance, use SPI DMA or a 16-bit parallel write loop.

---

## Physics code port

ESP32 has a **single-precision FPU** — your `f32` physics code runs at full speed (~1-2 cycles per float op). **No fixed-point needed.**

Changes from the desktop SDL version:

| SDL3 code | ESP32 equivalent |
|-----------|-----------------|
| `SDL_GetTicks()` | Cycle counter (`xthal_get_ccount()`) or TIMG timer |
| `SDL_SetRenderDrawColor` | Set `fill_color` variable |
| `SDL_RenderClear` | `fill_rect(fb, 0, 0, 320, 240, color)` |
| `SDL_RenderRect` | `draw_rect(fb, x, y, w, h, color)` |
| `SDL_RenderDebugText` | Bitmap font drawing (8x8 tiles) |
| `SDL_GetKeyboardState` | GPIO button reads |
| `SDL_RenderPresent` | `flush_framebuffer()` over SPI |
| `vsync` | Frame timer: `while (cycle_count() < target) {}` |

### Display dimensions

ILI9341 is **320×240** (landscape). The desktop version uses 800×600. Remap physics boundaries.

---

## Development workflow (recommended: Phase 0 → Phase 1 → Phase 2)

### Phase 0: Blink an LED

Before touching the TFT, prove the bare-metal pipeline works:

1. Install forked Zig
2. Write `build.zig` + `startup.zig` + `main.zig` that toggles a GPIO
3. Build: `zig build`
4. Convert to ESP32 image format (add bootloader header)
5. Flash with `esptool.py`
6. **Success criterion**: LED blinks at 1Hz

### Phase 1: Blue square on TFT

1. Add bitbanged SPI + ILI9341 driver
2. Write framebuffer in DRAM (`[320*240]u16`)
3. Fill blue rectangle at fixed position
4. Flush to display
5. **Success criterion**: Static blue square on screen

### Phase 2: Physics demo

1. Port kinematics code
2. Wire up buttons for input
3. Add frame timer
4. Moving square with physics
5. **Success criterion**: Physics demo running on TFT

---

## Flashing

### ESP32 bootloader requirement

The ESP32 ROM bootloader expects a specific **image header** before the app binary. The raw `.bin` from `zig build` won't boot directly. You need to either:

**A. Use the ESP-IDF bootloader** (easier)
- Flash the pre-built ESP-IDF bootloader at offset `0x1000`
- Flash the app at offset `0x10000`
- The bootloader handles cache init and jumps to your app

**B. Use `esptool.py`'s image generation** (untested)
```bash
esptool.py --chip esp32 elf2image --output firmware.bin physics-esp32.elf
esptool.py --chip esp32 write_flash 0x10000 firmware.bin
```

**C. Write your own image header** (research needed)
- ESP32 image header: 8-byte header + optional segment descriptors
- Format: magic(0xE9), segments, entry point, etc.
- Documented in ESP-IDF source: `components/bootloader_support/include/esp_image_format.h`

### Partition layout

| Offset | Size | Content |
|--------|------|---------|
| `0x1000` | ~32KB | Bootloader (from ESP-IDF) |
| `0x8000` | 4KB | Partition table |
| `0x10000` | ~1MB+ | Application firmware |
| `0x1F0000` | varies | (optional) filesystem, etc. |

### QEMU testing

```bash
qemu-system-xtensa -nographic -machine esp32 -kernel zig-out/bin/physics-esp32.elf
```

QEMU requires all code in iRAM (no flash cache emulation). Use a separate linker script (`esp32-qemu.ld`) that maps everything to iRAM/dRAM.

---

## Estimated effort

| Component | Lines | Difficulty | Time |
|-----------|-------|-----------|------|
| Toolchain setup | — | Medium | 30m |
| `build.zig` + linker script | ~80 | Medium | 1-2h |
| Startup code (reset, WDT, BSS) | ~60 | Hard | 2-3h |
| GPIO driver | ~40 | Easy | 30m |
| Bitbanged SPI | ~60 | Easy | 1h |
| ILI9341 init + protocol | ~150 | Medium | 2-3h |
| Framebuffer + drawing | ~80 | Easy | 30m |
| Physics port | ~100 | Easy | 30m |
| Input (buttons) | ~30 | Easy | 20m |
| Flashing pipeline | ~30 | Medium | 1h |
| **Total** | **~630** | | **~10-14h** |

Using bitbanged SPI (instead of register-level SPI driver) cuts ~200 lines and ~6-8 hours of development time, at the cost of slower frame rates (~15-30fps vs 60fps).

---

## Resources

- [ESP32 Technical Reference Manual (PDF)](https://www.espressif.com/sites/default/files/documentation/esp32_technical_reference_manual_en.pdf)
- [ESP32 datasheet](https://www.espressif.com/sites/default/files/documentation/esp32_datasheet_en.pdf)
- [ILI9341 datasheet](https://cdn-shop.adafruit.com/datasheets/ILI9341.pdf)
- [esp32-baremetal-zig](https://codeberg.org/kassane/esp32-baremetal-zig) — pure Zig reference implementation
- [zig-esp-idf-sample](https://github.com/kassane/zig-esp-idf-sample) — Zig + ESP-IDF hybrid
- [zig-espressif-bootstrap](https://github.com/kassane/zig-espressif-bootstrap) — forked Zig with Xtensa support
- [ESP32 image format](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/system/app_image_format.html)
