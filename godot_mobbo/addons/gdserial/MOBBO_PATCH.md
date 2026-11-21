# MoBBo patch for gdserial v0.3.4

## Why

LC1's HX711 clock (SCK) is wired to NodeMCU pin **D3 = GPIO0**. On NodeMCU
boards the CP2102 auto-program circuit pulls GPIO0 low whenever the host
asserts **DTR without RTS**. Stock gdserial (the Rust `serialport` crate) opens
Windows ports in exactly that state, so HX711 #1 is never clocked and LC1
reads `0` on both boards.

Measured on COM10 (2026-11-21):

| DTR | RTS | Result |
|-----|-----|--------|
| on  | on  | all 4 load cells OK |
| off | off | all 4 load cells OK |
| on  | off | LC1 = 0 every packet (stock gdserial state) |
| off | on  | ESP8266 held in reset, no data |

## What the patch changes (`mobbo_dtr.patch`)

- `GdSerialManager.open()` opens with `dtr_on_open(false)`.
- New `GdSerialManager.set_dtr(port, level)` and `set_rts(port, level)`.

`scripts/core/serial_link.gd` calls `set_dtr`/`set_rts` only when they exist,
and with the stock DLL it reports "LC1 reads exactly 0" instead of failing silently.

## Build

```
git clone --depth 1 --branch v0.3.4 https://github.com/SujithChristopher/gdserial.git
cd gdserial
git apply <path-to>/addons/gdserial/mobbo_dtr.patch
cargo build --release
copy target\release\gdserial.dll <project>\godot_mobbo\addons\gdserial\bin\windows-x86_64\gdserial.dll
```

Close Godot before replacing the DLL.

Alternative without a patched DLL: move LC1's SCK wire from D3 to D4 (GPIO2) on
both boards and change `HX711_SCK` in `s_mobbo/s_mobbo.ino` to `{D4, D6, D8, D2}`.
