# MoBBo Godot migration: two-board monitor

This is an initial serial monitor, not a complete port of the Unity application.
The Unity build settings include login, MoBBo test, Pong, space shooter, Flappy
Bird, coin collection, force display, weight shifting, and stepper scenes.
Those games, patient/session management, calibration, and logging still need
conversion and validation against the original build.

## Running on Windows

1. Install Godot 4 and Python 3. Install the bridge dependency with
   `py -m pip install pyserial`.
2. Flash each board with `s_mobbo.ino` and connect both via USB.
3. In a terminal run `py serial_bridge.py` from this directory.
4. Open `project.godot` in Godot and run the project. Refresh ports, select
   different left and right ports, and connect. The serial monitor in the
   Arduino IDE must be closed while the bridge uses the ports.

The bridge listens only on localhost port 23051. Both serial ports use 57600
baud and expect newline-terminated CSV packets containing four signed 24-bit
ADC readings. They are raw values, not forces in physical units. Sensor order,
tare, scale factors, and game-control mapping need to be established using
actual boards before game behavior can be validated. If a board stops sending,
the displayed reading remains the last received value.
