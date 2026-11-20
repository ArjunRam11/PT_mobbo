# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

MoBBo is a balance-board physical-therapy system: two force-sensing boards (4 load cells each,
read via HX711 amplifiers on an ESP8266/NodeMCU) drive a set of Unity minigames (pong, flappy
bird, coin collector, space shooter, a stepper/weight-shifting trainer, etc.) used for patient
rehab sessions. The repo currently holds three different, loosely related things:

- **Unity project** (repo root `Assets/`, `Packages/`, `ProjectSettings/`) — the actual
  therapy application. This is the primary, actively developed codebase.
- **`s_mobbo/s_mobbo.ino`** — firmware for the ESP8266 (NodeMCU) board that reads four HX711 load
  cells and streams them over serial as `adc1,adc2,adc3,adc4,boardno\r\n` at 115200 baud. `boardno`
  is a compile-time constant per physical board (`"0"` = left, `"1"` = right) — it self-identifies
  which board a line came from, independent of which USB port it's plugged into. (The old root-level
  duplicate of this file has been deleted; `s_mobbo/s_mobbo.ino` is now the only copy.)
- **`godot_mobbo/`** — an in-progress Godot port of the Unity app, now underway (see the dedicated
  section below for what exists and what doesn't).

Note the firmware/transport mismatch: the **Unity app** talks to boards over **WiFi/UDP**
(`MoBBoLibrary_WIFI.MoBBoUdpServer`, port 23000/23001 — see `AppData_WIFI.localPort/remotePort`),
while `s_mobbo.ino` and the **Godot app** talk over **USB serial**. These are two different board
firmwares/protocols for the same physical boards, not a shared one — don't assume data from one
path is compatible with the other. The Godot port deliberately uses serial, not WiFi/UDP, as its
live data source (see below) — this was an explicit decision, not a temporary gap.

## Running / building

This is a Unity 2021.3.40f1 project — there is no CLI build/test/lint pipeline in this repo.
Open the project in the Unity Editor (matching version) and use Play Mode / Build Settings.
The build's only registered scene is `Assets/wifi mobbo/scene/login_mobbo.unity`
(`Assets/Scenes/SampleScene.unity` is an unused default template scene). `com.unity.test-framework`
is a listed package dependency but no test assemblies exist in `Assets/`.

For the Godot app (`godot_mobbo/`): install Godot 4 (4.5, `gl_compatibility` renderer) and Python 3,
`py -m pip install pyserial`, flash both boards with `s_mobbo/s_mobbo.ino`, run `py serial_bridge.py`
from `godot_mobbo/`, then open `project.godot` in Godot. The serial monitor's original setup steps
are in `godot_mobbo/README.md`, but that file predates the login/hub scenes below and is stale on
scope — treat this CLAUDE.md section as current.

For the firmware: flash `s_mobbo.ino` to an ESP8266 (NodeMCU 1.0) via the Arduino IDE/CLI; close
any serial monitor before the Python bridge connects to the port.

## Unity project architecture

### Where the real app code lives

Almost all gameplay/app logic lives under **`Assets/wifi mobbo/script/`** — this is the active
WiFi-based implementation. Loose `.cs` files directly under `Assets/` (e.g. `BoardTiltController.cs`,
`StepperGameManager.cs`, `force.cs`, `login_handlr.cs`, `coin.cs`, `game_pong_ball.cs`) are also
part of the shipped app and reference the same `MoBBoLibrary_WIFI`/`AppData_WIFI`/`MoBBoServer`
types — they're just not organized into the `wifi mobbo` folder. `Assets/_CrashyRacing/` and
`Assets/Space Shooter/` are vendored third-party asset-store packages used for the racing/space
minigames; treat their contents as upstream, not project code.

### Core static/global state (not MonoBehaviours)

- **`MoBBoLibrary_WIFI`** (`Assets/wifi mobbo/script/MoBBoLibrary_WIFI.cs`) — transport layer.
  `MoBBoUdpServer` owns the UDP socket, device registration/ID assignment handshake
  (`MoBBoCommands` enum: `REGISTER`, `SET_ID`, `STREAM_ON/OFF`, etc.), and per-device raw-data
  logging (`DataLogger`, CSV with a fixed `DataHeader`). `MoBBoDeviceUDP` holds the last N raw
  packets per board (`FixedSizeQueue`) and exposes decoded force/position fields (`F1..F4`, `F`,
  `X`, `Y`) parsed as floats from a fixed 32-byte packet.
- **`AppData_WIFI`** (`Assets/wifi mobbo/script/AppData_WIFI.cs`) — app-wide session/timer/grid
  state. Holds the active `TherapySession_WIFI`, the UDP port constants, and `MoBBoGrid` (maps
  physical board layout to device IDs).
- **`MoBBoServer`** (static class at the bottom of `AppData_WIFI.cs`) — the glue most game scripts
  actually read from. Aggregates per-board `F` values across `AppData_WIFI.mGrid` into
  player/side-specific weight totals (`W`, `W_player1`, `W_player2`, `W_player1_ap`,
  `W_player2_ap`, `COP`, `COP_BottomBoard`, `COP_TopBoard`, etc.). Game scripts poll these static
  properties every `Update()` rather than subscribing to events — when changing how weight/COP is
  computed, this is the one place to change, but every consumer re-reads it per frame.
- **`login_handlr`** (`Assets/login_handlr.cs`) — not just login: it also defines the static
  session folder-path layout (`static string session_folder, gamedata_folder, rawdata_folder,
  boardset_up_folder, assess_folder`, plus per-game CSV path statics like `stepper_gamedata`,
  `pingpong_rawdata`) that every game script's `Start()` calls `Directory.CreateDirectory` on, and
  reads/writes `MOBBO_MASTERLIST.csv` under `Application.dataPath/data/` for patient lookup/signup.
  Patient identity, session folder structure, and the on-disk game-data layout are all defined here.

### Game scripts pattern

Each minigame (pong, floppy bird, coin collector, ball-roller/tilt board, stepper) is a
`MonoBehaviour` that: reads weight/COP values from `MoBBoServer` statics in `Update()`, drives
Unity UI/physics (`Rigidbody2D` forces, `Image` color/visibility toggles) from thresholds on those
values, and on trial start/stop calls into `MoBBoServer.server.StartLogging_p(...)` /
`StopLogging()` plus writes its own per-trial summary CSV via the `login_handlr`-provided paths.
Scene transitions go through `SceneManager.LoadScene("2mb")` (the hub/menu scene) rather than a
central navigation controller. There's no shared base class for these managers — new minigames are
expected to follow the same copy-pasted `Start/Update` + static-polling pattern, not a new
abstraction.

## Godot conversion (`godot_mobbo/`)

Converting the Unity app to Godot, scene by scene, keeping the same overall structure. Current
state (update this list as work continues — it's the map of what's left):

The app's entry point is `scenes/login/login.tscn` (`project.godot`'s `run/main_scene`), not
`main.tscn` — `main.tscn` is now just the "Board Diagnostics" screen, reachable from the hub.

**Done:**
- **Data pipeline, over serial (not WiFi/UDP — a deliberate pivot from the Unity app's transport):**
  `serial_bridge.py` relays both boards' serial lines over local TCP (`127.0.0.1:23051`), tagging
  each line's side (`left`/`right`) from the firmware's own `boardno` field rather than from which
  port the user picked. **`scripts/core/serial_link.gd` (autoload `SerialLink`) owns the one TCP
  connection to that bridge and the latest raw ADC per board** — every scene reads this shared
  autoload instead of each managing its own socket, mirroring how Unity's `AppData_WIFI.Start()`/
  `MoBBoServer` run once and every game scene just polls the resulting statics each frame.
  `scripts/core/board_data.gd` (autoload `BoardData`) turns raw ADC readings into per-sensor force
  (`Force_i = raw_adc_i * gain_i - off_i`, calibration constants measured for the right board; left
  board currently reuses them) and center-of-pressure, both per-board and combined across both
  boards in a left-board-origin frame (`right_board_offset` encodes the boards' physical
  arrangement — currently an edge-to-edge, zero-gap assumption, not a measured value; fix it there
  if the real rig differs). `BoardData` also provides **per-trial raw logging**
  (`start_trial_log`/`log_trial_frame`/`stop_trial_log`): rows accumulate in memory and flush once
  at stop, the same pattern as Unity's `DataLogger`/`MoBBoDeviceUDP`, with a header shaped like
  Unity's `MoBBoDeviceUDP.DataHeader` (`side,systime,devtime,f1,f2,f3,f4,x,y,F,annotation` — "ID"
  became "side" since this rig is always exactly two boards, not N registered devices).
  `main.tscn`/`main.gd` (the "Board Diagnostics" screen, off the hub) displays `SerialLink`'s live
  data via `BoardData`'s math instead of raw ADC dumps.
- **Session/config foundation**: `scripts/core/app_data.gd` (autoload `AppData`, ~ `AppData_WIFI`'s
  session/timer/grid state), `scripts/core/session_paths.gd` (autoload `SessionPaths`, ~
  `login_handlr`'s session folder layout + `MOBBO_MASTERLIST.csv` patient lookup), plus
  `scripts/core/app_config.gd` (autoload `AppConfig`), `MoBBoGrid`, `MoBBoDeviceUDP`,
  `MoBBoDataLogger`, and a UDP layer (`scripts/core/mobbo_network.gd`) ported from
  `MoBBoLibrary_WIFI` but **not registered as an autoload** — serial superseded it as the live data
  path, so it's dead code kept for reference only.
- **Login/signup scene** (`scenes/login/`) — hospital-number lookup + new-patient signup form,
  using `SessionPaths`. Deliberately drops one piece of the original `login_handlr.cs` behavior: a
  global Return-key handler in `Update()` that re-triggered login from anywhere in the scene,
  which looked like a leftover debug hook rather than an intended second entry point.
- **Hub scene** (`scenes/hub/`) — the `"2mb"` equivalent. Lists every in-scope game as a button; any
  whose `scene` path is still `""` in `GAME_ENTRIES` is a disabled "(soon)" placeholder (not
  silently omitted), so that list is the authoritative "what's left to port" marker. `_CrashyRacing`
  and `Space Shooter` are intentionally not listed at all (out of scope per instruction, not just
  deferred).
- **Assessment scene** (`scenes/assessment/`) — port of the reachable-at-runtime parts of
  `TestScene_handler.cs` (a 1500-line file that's mostly dead board-setup/grid-visualization code
  for Unity's variable NxM board grid, which doesn't apply to this fixed two-board rig — see that
  file if a from-scratch board-setup/calibration-grid screen is ever wanted). Ported: the
  medial-lateral (left/right) limits-of-stability reach capture
  (`find_Min_max_ML_reach`/`button_min_max_ml`/`write_csv_min_max_ml`, writing
  `min_max_dist_ml.csv` with the same header/columns as Unity) and timed-trial raw logging via
  `BoardData`. **Not ported:** the anterior-posterior (front/back) reach variant — it assumes a
  front-back board pair, which this left/right rig doesn't have, so it isn't physically meaningful
  here. Lean-detection thresholds are this port's own (geometry-based), not copied from Unity's
  `COP.x < 55`/`> 60` — those were tuned to Unity's different multi-board coordinate frame.
- **Force Display scene** (`scenes/force_display/`) — port of `force.cs`'s core role (see live
  per-sensor force and COP at a glance), built on `scripts/ui/board_view.gd` (`class_name
  BoardView`, a reusable to-scale `_draw()`-based visualization of one board: corner dot/text size
  scaled by force, like Unity's font-size-by-force, plus a COP marker). Not ported: Unity's
  draw-a-rectangle-from-typed-dimensions overlay and per-corner `MeshRenderer` color tinting —
  cosmetic extras on the same underlying data, not the data itself.
- **Four minigames**, all weight/COP-controlled via `BoardData`/`SerialLink`, all built in code on
  a dedicated reusable `scripts/ui/*_arena.gd` `Control` (pure view, `_draw()`-based, matching
  `BoardView`'s pattern) plus a scene script owning state:
  - **Weight Shifting** (`scenes/weight_shifting/`, `TiltArena`) — port of `BoardTiltController.cs`:
    board tilts by left/right weight difference, a ball rolls under gravity-along-the-slope.
    `MAX_TILT_DEG` is 25 here, not Unity's 60 — just a legibility choice for the drawn board, not a
    data/logic change. Unity's "paddle width" level knob didn't apply (no paddle in this game) and
    wasn't ported; only the speed/drag half of the level system was.
  - **Ping Pong** (`scenes/ping_pong/`, `PongArena`) — port of `Gamescript_pong.cs` +
    `computer_paddle.cs`, with the player paddle driven by weight (`ping.cs`'s `playerCOP()`)
    instead of keyboard/mouse. Unity's version mixed 3D `Rigidbody` physics into a 2D-looking game
    with some unresolved internal inconsistencies (two different scripts both tried to drive the
    "computer" paddle); this is a clean 2D reimplementation of the same mechanic (weight-controlled
    bottom paddle, ball-chasing AI top paddle, score to 5), not a bug-for-bug clone. Writes
    `pingpong_gamedata`'s per-rally CSV with Unity's exact header.
  - **Coin Collector** (`scenes/coin_collector/`, `CoinArena`) — port of `coin.cs`/`collector.cs`/
    `silvercoin.cs`/`genrator.cs`: a weight-controlled collector catches falling coins (+1 score)
    and must avoid falling bombs (`silvercoin.cs` — despite the name, it's not a bonus; catching
    one ends the game). Unity had no CSV/trial logging for this game anywhere in those four files,
    so none was added here either.
  - **Floppy Bird** (`scenes/floppy_bird/`, `FlappyArena`) — port of `BirdScript.cs` +
    `PipeSpawnScript.cs`/`PipeMoveScript.cs`/`HeartSystem.cs`: the bird's vertical position tracks
    a moving-average-smoothed combined COP.y (not a flap/jump input), scaled across a narrow
    lean band read from the ML assessment CSV. Carried over as-is, including Unity's odd reuse of
    the medial-lateral assessment's `min_gcop_y` as the vertical baseline for what is otherwise an
    anterior-posterior-feeling mechanic — that's Unity's actual behavior, not a porting mistake.
  - All four read reach limits via `SessionPaths.get_ml_limits()` (new), which parses
    `min_max_dist_ml.csv` the same way `BirdScript.cs`/`ping.cs`/`collector.cs` did, except it
    uses the **last** (most recent) row rather than Unity's **first** row — always reading the
    first-ever assessment forever looked like an oversight for a file designed to accumulate one
    row per assessment, not an intended "baseline" design. Falls back to `BoardData`'s physical
    combined-COP range if no assessment has been recorded yet.
- **Shared UI theme** (`scripts/ui/ui_theme.gd`, autoload `UiTheme`) — one Theme built in code
  (not a hand-authored `.tres`), used by every scene above. Palette/sizing follow the
  accessibility-focused "accessible-and-ethical" style (7:1 text contrast target, 44px+ touch
  targets, visible 3px focus rings, no body text under 16px) rather than the softer neumorphism a
  first design-system pass suggested, since this app's real users include clinicians and patients
  in a clinical setting. Includes a themed `ProgressBar` and `UiTheme.set_status(label, message,
  "error"|"success"|"neutral")` — the one shared status-message convention (color never carries
  meaning alone; text is also prefixed "Error:"/"Success:"). Scenes build their UI in code (no
  hand-authored `.tscn` node trees beyond a bare root `Control`) and should keep using `UiTheme`'s
  `make_*`/`set_status` helpers rather than raw `Button.new()`/`Label.new()` or ad-hoc colors, so
  touch targets, spacing, and color semantics (primary/accent/destructive/secondary) stay
  consistent across every screen.

**Not started:** stepper (blocked — see below), board setup/test, and user info.
`_CrashyRacing`/`Space Shooter` are out of scope entirely (not just deferred). `AppConfig`/the UDP
`MoBBoGrid` layer still aren't exercised by any real scene.

**Stepper is blocked on a hardware-geometry mismatch, not yet resolved:** `StepperGameManager.cs`
reads `W_player2_ap`/`W_player1_ap` and `COP_BottomBoard`/`COP_TopBoard` — i.e. it assumes the two
boards are arranged **front/back** (one behind the other, for a stepping motion). This rig's
boards are **left/right** side-by-side (`Boardno` 0/1, confirmed by the firmware and by how
`BoardData.combined_cop` is defined). Porting Stepper as-is would silently claim front/back
stepping detection on hardware that can't produce it. Needs a decision before implementing: either
reinterpret the "front/back" mechanic as a left-to-right full weight transfer, or treat Stepper as
needing different/additional hardware and scope it out like the vendored kits.

**Testing:** a Godot 4.6 executable is at `D:\Godot_v4.6.2-stable_win64_console.exe` (console
build — prints to stdout, unlike the windowed one; `project.godot` itself was upgraded in-place to
`config/features=PackedStringArray("4.6")` the first time it was opened in this 4.6 editor). To
sanity-check scripts/scenes headlessly:
`"/d/Godot_v4.6.2-stable_win64_console.exe" --headless --path . res://path/to/scene.tscn --quit-after 5`
(swap the scene path, or drop it to run `run/main_scene`). If `class_name` types report as
"not found" on a fresh clone, run once with `--headless --editor --quit --path .` first to force
Godot to build its global script-class cache, then re-run the above.

Without real boards attached, the data pipeline (`SerialLink`'s TCP protocol through `BoardData`'s
calibration/COP math) can still be verified end-to-end with a throwaway Python script standing in
for `serial_bridge.py`: open a TCP server on `127.0.0.1:23051` and stream fixed
`{"type":"data","side":"left"/"right","adc":[...]}` lines with a known ADC value, then compare
`BoardData`'s computed force/COP against a hand-calculated expected value (e.g. `print()` from a
scene's `_process()` once `SerialLink.has_left_data()`/`has_right_data()` are true, read via
`--headless ... --quit-after N`). This caught 3 real bugs during initial development and is the
way to re-verify the pipeline after touching `BoardData`/`SerialLink` without needing hardware.
