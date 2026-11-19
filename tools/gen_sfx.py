"""効果音 9 個(仕様書 §9.13 の 9 種)を合成して assets/sfx/<名前>.wav に書く。標準ライブラリだけ・乱数は使わない(何度回しても同じバイト列)。
16bit PCM・モノラル・22050 Hz。

    python tools/gen_sfx.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
RATE = 22050
TAU = 2 * math.pi


def tone(buf, at, dur, f0, f1=None, gain=1.0, decay=0.0, square=False):
    """音 1 本を buf に足す。f0→f1 へ直線で動き、exp(-decay*t) で消える。square なら矩形に近い音(奇数倍音 3 本)。"""
    f1 = f1 or f0
    start = int(at * RATE)
    n = int(dur * RATE)
    while len(buf) < start + n:
        buf.append(0.0)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        e = gain * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE), i / (0.001 * RATE))
        s = math.sin(phase)
        if square:
            s += math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5
        buf[start + i] += e * s
        phase += TAU * (f0 + (f1 - f0) * i / n) / RATE


def write(name, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def main():
    b = []
    tone(b, 0, 0.06, 500, 1400, decay=25)  # cast_ok: 腕が伸びる短い音
    write("cast", b, 0.35)
    b = []
    tone(b, 0, 0.012, 1800, 900, decay=80)
    tone(b, 0.005, 0.12, 660, 520, decay=22)  # stick: 吸い付く音(連続で半音ずつ上げて鳴らす)
    write("stick", b, 0.7)
    b = []
    tone(b, 0, 0.1, 240, 170, square=True, decay=14)  # cast_miss: 低く短い音
    write("cast_miss", b, 0.4)
    b = []
    tone(b, 0, 0.07, 150, 90, decay=30)  # land: 着地
    write("land", b, 0.5)
    b = []
    for k in range(3):
        tone(b, k * 0.035, 0.025, 2600 - k * 300, 2000, decay=90)  # crumble_start: ひび
    write("crack", b, 0.3)
    b = []
    for k, f in enumerate([420, 330, 250, 190]):
        tone(b, k * 0.04, 0.12, f, f * 0.8, square=True, decay=18)  # crumble: 崩れる
    write("crumble", b, 0.45)
    b = []
    tone(b, 0, 0.3, 200, 80, square=True, decay=6)  # miss: 低い音
    write("miss", b, 0.6)
    b = []
    tone(b, 0, 0.07, 880, decay=14)
    tone(b, 0.06, 0.12, 1320, decay=14)  # checkpoint: 短い合図
    write("checkpoint", b, 0.5)
    b = []
    for k, f in enumerate([523, 659, 784, 1047]):
        tone(b, k * 0.1, 0.3, f, decay=6)  # goal
    write("goal", b, 0.6)
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(list(OUT.glob('*.wav')))} 個、合計 {total:,} バイト")


if __name__ == "__main__":
    main()
