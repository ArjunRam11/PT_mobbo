"""Local serial bridge for the Godot two-board monitor. Requires pyserial."""
import json
import socket
import threading
import time

import serial
from serial.tools import list_ports

HOST, PORT = "127.0.0.1", 23051
BAUD = 57600


def parse_packet(line):
    parts = line.decode("ascii").strip().split(",")
    if len(parts) != 4:
        raise ValueError("expected four values")
    values = [int(part) for part in parts]
    if any(value < -8388608 or value > 8388607 for value in values):
        raise ValueError("ADC value out of range")
    return values


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

    def read_board(side, port):
        while not stop.is_set() and port.is_open:
            try:
                line = port.readline()
                if line and line.endswith(b"\n"):
                    try:
                        values = parse_packet(line)
                    except (ValueError, UnicodeDecodeError):
                        continue
                    send({"type": "data", "side": side, "values": values})
            except (serial.SerialException, OSError, TypeError) as exc:
                if port.is_open:
                    send({"type": "error", "message": f"{side} board: {exc}"})
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
                        left, right = request.get("left"), request.get("right")
                        available = {p.device for p in list_ports.comports()}
                        if not left or not right or left == right or left not in available or right not in available:
                            raise ValueError("Select two different available serial ports.")
                        disconnect()
                        try:
                            ports["left"] = serial.Serial(left, BAUD, timeout=0.2)
                            ports["right"] = serial.Serial(right, BAUD, timeout=0.2)
                        except (serial.SerialException, OSError):
                            disconnect()
                            raise
                        for side, port in ports.items():
                            threading.Thread(target=read_board, args=(side, port), daemon=True).start()
                        send({"type": "status", "message": f"Connected: left {left}, right {right}. Waiting for data."})
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
            serve_client(client)


if __name__ == "__main__":
    main()
