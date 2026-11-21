"""Local serial bridge for the Godot two-board monitor. Requires pyserial."""
import json
import socket
import threading

import serial
from serial.tools import list_ports

HOST, PORT = "127.0.0.1", 23051
BAUD = 115200  # matches Serial.begin(115200) in s_mobbo.ino


def parse_packet(line):
    # s_mobbo.ino sends "adc1,adc2,adc3,adc4,boardno\r\n" -- 4 signed 24-bit
    # raw ADC readings plus a self-identifying board number (0 = left board,
    # 1 = right board, see the Boardno constant in the firmware).
    parts = line.decode("ascii").strip().split(",")
    if len(parts) != 5:
        raise ValueError("expected four ADC values plus a board number")
    adc = [int(part) for part in parts[:4]]
    if any(value < -8388608 or value > 8388607 for value in adc):
        raise ValueError("ADC value out of range")
    boardno = int(parts[4])
    if boardno not in (0, 1):
        raise ValueError("boardno must be 0 (left) or 1 (right)")
    side = "left" if boardno == 0 else "right"
    return side, adc


def serve_client(client):
    ports = {}
    send_lock = threading.Lock()
    stop = threading.Event()

    def send(message):
        try:
            with send_lock:
                client.sendall((json.dumps(message) + "\n").encode())
        except OSError:
            stop.set()

    def disconnect():
        for port in list(ports.values()):
            try:
                port.close()
            except serial.SerialException:
                pass
        ports.clear()

    def read_board(label, port):
        # `label` (the port device name) is only used for error messages --
        # which physical board ("left"/"right") a line belongs to is read
        # from its own boardno field, not from which port it arrived on.
        pending = bytearray()
        while not stop.is_set() and port.is_open:
            try:
                chunk = port.read_until(b"\n", 256)
                if chunk:
                    pending.extend(chunk)
                if pending.endswith(b"\n"):
                    line = bytes(pending)
                    pending.clear()
                    try:
                        side, adc = parse_packet(line)
                    except (ValueError, UnicodeDecodeError):
                        continue
                    send({"type": "data", "side": side, "adc": adc})
                elif len(pending) >= 256:
                    # A valid packet is much shorter; discard malformed input.
                    pending.clear()
            except (serial.SerialException, OSError, TypeError) as exc:
                if port.is_open:
                    send({"type": "error", "message": f"{label}: {exc}"})
                break

    try:
        with client, client.makefile("r", encoding="utf-8") as requests:
            for line in requests:
                try:
                    request = json.loads(line)
                    command = request.get("cmd")
                    if command == "ports":
                        send({"type": "ports", "ports": sorted(p.device for p in list_ports.comports())})
                    elif command == "disconnect":
                        disconnect()
                        send({"type": "status", "message": "Boards disconnected."})
                    elif command == "connect":
                        port_a, port_b = request.get("left"), request.get("right")
                        available = {p.device for p in list_ports.comports()}
                        if not port_a or not port_b or port_a == port_b or port_a not in available or port_b not in available:
                            raise ValueError("Select two different available serial ports.")
                        disconnect()
                        try:
                            ports["a"] = serial.Serial(port_a, BAUD, timeout=0.2)
                            ports["b"] = serial.Serial(port_b, BAUD, timeout=0.2)
                        except (serial.SerialException, OSError):
                            disconnect()
                            raise
                        for port in ports.values():
                            threading.Thread(target=read_board, args=(port.port, port), daemon=True).start()
                        send({"type": "status", "message": f"Connected: {port_a}, {port_b}. Waiting for data."})
                except (ValueError, TypeError, serial.SerialException, OSError) as exc:
                    send({"type": "error", "message": str(exc)})
    finally:
        stop.set()
        disconnect()


def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((HOST, PORT))
        server.listen(1)
        print(f"Serial bridge listening on {HOST}:{PORT}", flush=True)
        while True:
            client, _ = server.accept()
            try:
                serve_client(client)
            except (ConnectionError, OSError) as exc:
                print(f"Client disconnected: {exc}", flush=True)


if __name__ == "__main__":
    main()
