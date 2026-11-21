"""色の板のコントラスト比を出す(ui/kit.gd の色。WCAG の相対輝度)。字は 4.5:1、大きな字と押せる物の縁は 3:1 を下回ったら失敗にする。
ui/kit.gd の const C_* = Color("RRGGBB") を読むので、色を変えたら回し直す。

    python tools/contrast.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# (前の色, 後ろの色, 下限, 何か)
PAIRS = [
    ("C_TEXT", "C_BG", 4.5, "ふだんの字 / いちばん暗い背景"),
    ("C_TEXT", "C_BG_TOP", 4.5, "ふだんの字 / 明るい側の背景"),
    ("C_TEXT", "C_PANEL", 4.5, "ふだんの字 / 二番目のボタン・枠"),
    ("C_DIM", "C_BG", 4.5, "弱い字 / 背景"),
    ("C_DIM", "C_BG_TOP", 4.5, "弱い字 / 明るい側の背景"),
    ("C_DIM", "C_PANEL", 4.5, "弱い字 / 枠の中"),
    ("C_INK", "C_CORAL", 4.5, "一番目のボタンの字 / 珊瑚"),
    ("C_INK", "C_AQUA", 4.5, "選んだ値の字 / 水色"),
    ("C_INK", "C_SAND", 4.5, "新しい記録の札の字 / 砂"),
    ("C_FAST", "C_BG", 4.5, "速い差 / 背景"),
    ("C_FAST", "C_PANEL", 4.5, "速い差 / 枠の中"),
    ("C_CORAL", "C_BG", 3.0, "遅れた区画の字(太字 26)/ 背景"),
    ("C_SAND", "C_BG", 4.5, "記録の字 / 背景"),
    ("C_AQUA", "C_BG", 3.0, "フォーカスの輪 / 背景"),
    ("C_AQUA", "C_BG_TOP", 3.0, "フォーカスの輪 / 明るい側の背景"),
    ("C_EDGE", "C_BG", 3.0, "二番目のボタンの縁 / 背景"),
    ("C_SPIKE", "C_BG", 3.0, "トゲ / 背景"),
    ("C_WALL_EDGE", "C_BG", 3.0, "壁の縁 / 背景"),
    # 塔の上の方(区画 5 とゴールの段)の背景。v0.2.0 はトゲ / #18202B が 4.9
    ("C_SPIKE", "C_FIELD_TOP", 4.0, "トゲ / 塔の上の背景"),
    ("C_WALL_EDGE", "C_FIELD_TOP", 3.0, "壁の縁 / 塔の上の背景"),
    ("C_TAKO", "C_FIELD_TOP", 3.0, "タコ / 塔の上の背景"),
    ("C_BRITTLE", "C_FIELD_TOP", 3.0, "もろい壁 / 塔の上の背景"),
    ("C_SLICK", "C_FIELD_TOP", 3.0, "ツルツルの壁 / 塔の上の背景"),
    # v0.3.1: 遊びの画面の上からの光(水の青緑の差しと光の筋)が一番強く重なる所
    ("C_SPIKE", "C_GLOW", 4.0, "トゲ / 遊びの画面の光の下"),
    ("C_WALL_EDGE", "C_GLOW", 3.0, "壁の縁 / 遊びの画面の光の下"),
    ("C_TAKO", "C_GLOW", 3.0, "タコ / 遊びの画面の光の下"),
    ("C_BRITTLE", "C_GLOW", 3.0, "もろい壁 / 遊びの画面の光の下"),
    ("C_SLICK", "C_GLOW", 3.0, "ツルツルの壁 / 遊びの画面の光の下"),
]


def lum(hex6: str) -> float:
    out = []
    for i in (0, 2, 4):
        c = int(hex6[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2]


def ratio(a: str, b: str) -> float:
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    text = (ROOT / "ui" / "kit.gd").read_text(encoding="utf-8")
    colors = dict(re.findall(r'const (C_\w+) := Color\("([0-9A-Fa-f]{6})"\)', text))
    bad = 0
    for fg, bg, need, what in PAIRS:
        r = ratio(colors[fg], colors[bg])
        ok = r >= need
        bad += not ok
        print(f"{'OK' if ok else 'NG'}  {r:5.2f} (>= {need})  {what}  {fg} #{colors[fg]} / {bg} #{colors[bg]}")
    print("全部 OK" if bad == 0 else f"NG {bad} 件")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
