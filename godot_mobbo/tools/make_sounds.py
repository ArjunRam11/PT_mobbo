"""Generates every game sound effect and music loop as .wav into ../sounds/.

All sounds are synthesized here (no third-party samples), so they can be
tweaked and regenerated:   python tools/make_sounds.py
Stdlib only. 22.05 kHz mono 16-bit. Loops (music_*, roll) carry a WAV "smpl"
loop chunk so Godot's importer ("Detect from WAV") loops them seamlessly;
their note tails are wrapped around the loop point so the seam is silent.
"""
import math
import os
import random
import struct

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")


# -- primitives ---------------------------------------------------------------

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "tri":
        return 4 * abs(p - 0.5) - 1
    if kind == "soft":  # rounded square: fundamental + a little 3rd/5th
        s = 2 * math.pi * p
        return math.sin(s) + math.sin(3 * s) / 4 + math.sin(5 * s) / 10
    if kind == "saw":
        return 2 * p - 1
    raise ValueError(kind)


def tone(freq, dur, kind="sine", attack=0.004, decay=0.2, vol=0.5, to_freq=None, vibrato=0.0):
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq if to_freq is None else freq + (to_freq - freq) * (t / dur)
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * 5.5 * t)
        phase += f / SR
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= math.exp(-t / decay) if decay > 0 else 1.0
        # 5 ms fade at the very end: no clicks
        env *= min(1.0, (dur - t) / 0.005)
        out[i] = osc(kind, phase) * env * vol
    return out


def noise(dur, decay=0.2, vol=0.5, lowpass=0.2, attack=0.002, seed=1):
    rnd = random.Random(seed)
    n = int(dur * SR)
    out = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / SR
        y += lowpass * (rnd.uniform(-1, 1) - y)
        env = min(1.0, t / attack) * (math.exp(-t / decay) if decay > 0 else 1.0)
        env *= min(1.0, (dur - t) / 0.005)
        out[i] = y * env * vol / max(0.15, math.sqrt(lowpass))
    return out


def mix(dst, src, at=0.0, gain=1.0, wrap=False):
    start = int(at * SR)
    for i, v in enumerate(src):
        j = start + i
        if wrap:
            j %= len(dst)
        elif j >= len(dst):
            dst.extend([0.0] * (j - len(dst) + 1))
        dst[j] += v * gain
    return dst


def seq(*parts):
    """parts: (start_seconds, samples)"""
    out = []
    for at, s in parts:
        mix(out, s, at)
    return out


def normalize(s, peak=0.85):
    m = max(1e-9, max(abs(v) for v in s))
    return [v * peak / m for v in s]


def write_wav(name, samples, loop=False):
    os.makedirs(OUT, exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples)
    chunks = b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16)
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if loop:
        smpl = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<IIIIII", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    riff = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(riff)
    print("wrote", name, "%.2fs" % (len(samples) / SR))


# -- sound effects --------------------------------------------------------------

def sfx():
    write_wav("ui_click", normalize(tone(1400, 0.05, "sine", decay=0.015, vol=0.6), 0.5))
    write_wav("start", normalize(seq(
        (0.00, tone(midi(72), 0.16, "soft", decay=0.08)),
        (0.09, tone(midi(76), 0.16, "soft", decay=0.08)),
        (0.18, tone(midi(79), 0.35, "soft", decay=0.15)),
    ), 0.7))
    write_wav("coin", normalize(seq(
        (0.00, tone(midi(83), 0.09, "soft", decay=0.05, vol=0.5)),
        (0.07, tone(midi(88), 0.35, "soft", decay=0.12, vol=0.5)),
    ), 0.7))
    boom = tone(120, 0.9, "sine", decay=0.25, vol=0.9, to_freq=40)
    mix(boom, noise(0.9, decay=0.22, vol=0.8, lowpass=0.08, seed=3))
    mix(boom, noise(0.25, decay=0.05, vol=0.5, lowpass=0.6, seed=4))
    write_wav("bomb", normalize(boom, 0.9))
    write_wav("fuse", normalize(noise(0.45, decay=0.3, vol=0.4, lowpass=0.7, attack=0.05, seed=5), 0.35))
    write_wav("score", normalize(seq(
        (0.00, tone(midi(79), 0.12, "tri", decay=0.06)),
        (0.06, tone(midi(84), 0.30, "tri", decay=0.12)),
        (0.06, tone(midi(91), 0.30, "sine", decay=0.10, vol=0.25)),
    ), 0.65))
    write_wav("hit", normalize(seq(
        (0.0, tone(320, 0.35, "saw", decay=0.12, vol=0.4, to_freq=110)),
        (0.0, noise(0.15, decay=0.05, vol=0.4, lowpass=0.3, seed=6)),
    ), 0.7))
    write_wav("paddle", normalize(tone(660, 0.12, "soft", decay=0.04, to_freq=520), 0.6))
    write_wav("paddle_cpu", normalize(tone(440, 0.12, "soft", decay=0.04, to_freq=350), 0.5))
    write_wav("wall", normalize(tone(900, 0.06, "sine", decay=0.02), 0.35))
    write_wav("point_win", normalize(seq(
        (0.00, tone(midi(76), 0.14, "soft", decay=0.07)),
        (0.10, tone(midi(83), 0.35, "soft", decay=0.14)),
    ), 0.65))
    write_wav("point_lose", normalize(seq(
        (0.00, tone(midi(67), 0.16, "tri", decay=0.08)),
        (0.12, tone(midi(60), 0.40, "tri", decay=0.16)),
    ), 0.6))
    fan = []
    for k, (n, at, d) in enumerate([(72, 0.0, 0.12), (76, 0.12, 0.12), (79, 0.24, 0.12), (84, 0.36, 0.7)]):
        mix(fan, tone(midi(n), d + 0.25, "soft", decay=d, vol=0.5), at)
        mix(fan, tone(midi(n - 12), d + 0.25, "sine", decay=d, vol=0.3), at)
    write_wav("win", normalize(fan, 0.75))
    write_wav("game_over", normalize(seq(
        (0.00, tone(midi(67), 0.25, "tri", decay=0.12)),
        (0.20, tone(midi(63), 0.25, "tri", decay=0.12)),
        (0.40, tone(midi(60), 0.70, "tri", decay=0.30, vibrato=0.01)),
    ), 0.65))
    write_wav("level_up", normalize(tone(500, 0.18, "soft", decay=0.08, to_freq=900), 0.5))
    write_wav("level_down", normalize(tone(900, 0.18, "soft", decay=0.08, to_freq=500), 0.5))
    knock = tone(180, 0.18, "sine", decay=0.04, to_freq=120)
    mix(knock, noise(0.08, decay=0.015, vol=0.6, lowpass=0.35, seed=7))
    write_wav("bump", normalize(knock, 0.7))
    write_wav("rec_start", normalize(seq((0.0, tone(880, 0.1, "sine", decay=0.05)), (0.12, tone(1320, 0.18, "sine", decay=0.07))), 0.5))
    write_wav("rec_stop", normalize(seq((0.0, tone(1320, 0.1, "sine", decay=0.05)), (0.12, tone(880, 0.18, "sine", decay=0.07))), 0.5))
    # Rolling marble: low rumble loop with a slow wobble (wrapped -> seamless).
    dur = 1.0
    roll = [0.0] * int(dur * SR)
    rnd = random.Random(9)
    y = y2 = 0.0
    for i in range(len(roll)):
        y += 0.05 * (rnd.uniform(-1, 1) - y)
        y2 += 0.05 * (y - y2)
        roll[i] = y2 * (0.8 + 0.2 * math.sin(2 * math.pi * 4 * i / len(roll)))
    # crossfade the seam
    n = int(0.1 * SR)
    for i in range(n):
        k = i / n
        roll[i] = roll[i] * k + roll[len(roll) - n + i] * (1 - k)
    write_wav("roll", normalize(roll[: len(roll) - n], 0.6), loop=True)


# -- music loops ----------------------------------------------------------------

def music(name, bpm, chords, arp_pattern, lead="tri", drums=False, pad_vol=0.12, arp_vol=0.16, bass_vol=0.22, repeats=2):
    beat = 60.0 / bpm
    bar = beat * 4
    bars = len(chords) * repeats
    total = bars * bar
    out = [0.0] * int(total * SR)
    for b in range(bars):
        chord = chords[b % len(chords)]
        t0 = b * bar
        # pad: slow swell, released by the end of the bar
        for n in chord:
            p = tone(midi(n), bar * 1.1, "sine", attack=bar * 0.35, decay=bar * 0.9, vol=pad_vol, vibrato=0.003)
            mix(out, p, t0, wrap=True)
        # bass on beats 1 and 3
        for k in (0, 2):
            mix(out, tone(midi(chord[0] - 12), beat * 1.8, "sine", attack=0.01, decay=beat * 0.8, vol=bass_vol), t0 + k * beat, wrap=True)
        # arpeggio, 8th notes
        second_half = b >= len(chords)
        for k, idx in enumerate(arp_pattern):
            if idx is None:
                continue
            note = chord[idx % len(chord)] + 12 * (idx // len(chord)) + 12
            if second_half and k % 4 == 3:
                note += 12
            mix(out, tone(midi(note), beat * 0.9, lead, attack=0.005, decay=beat * 0.35, vol=arp_vol), t0 + k * beat / 2, wrap=True)
        if drums:
            for k in range(4):
                kick = tone(110, 0.25, "sine", decay=0.06, vol=0.45, to_freq=45)
                mix(out, kick, t0 + k * beat, wrap=True)
                mix(out, noise(0.06, decay=0.015, vol=0.12, lowpass=0.9, seed=b * 8 + k), t0 + k * beat + beat / 2, wrap=True)
    write_wav(name, normalize(out, 0.8), loop=True)


def all_music():
    # Coin Collector: calm night, A minor
    music("music_coin", 84, [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]],
          [0, 1, 2, 3, 2, 1, 0, None], lead="tri")
    # Floppy Bird: airy dusk, F major, lydian-ish lift
    music("music_bird", 96, [[53, 57, 60], [55, 59, 62], [57, 60, 64], [52, 55, 59]],
          [0, 2, 1, 3, 2, 4, 3, 1], lead="sine", arp_vol=0.18)
    # Ping Pong: upbeat, C major, light kick/hat
    music("music_pong", 116, [[48, 52, 55], [57, 60, 64], [53, 57, 60], [55, 59, 62]],
          [0, None, 2, 1, 3, None, 2, 1], lead="soft", drums=True, arp_vol=0.12)
    # Weight Shifting: slow ambient, D dorian
    music("music_tilt", 70, [[50, 53, 57], [55, 59, 62], [53, 57, 60], [48, 52, 55]],
          [0, None, 2, None, 1, None, 3, None], lead="sine", pad_vol=0.16, arp_vol=0.14)


if __name__ == "__main__":
    sfx()
    all_music()
