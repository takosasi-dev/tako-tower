"""同梱する字体 Noto Sans JP(SlingArc と同じ。太さの軸は残す)を、画面に出す文字だけに絞る(RootCall の tools/subset_font.py の作り)。
core/strings.gd の文字列リテラルの全文字と、ASCII の印字できる文字、画面で使う記号を集めて絞り、assets/fonts/ に書く。
原本は google/fonts の固定コミットから取り、sha256 を照らす。tools/font_src/ に置き、git には入れない。文言を足したら回し直す。

    pip install fonttools
    python tools/subset_font.py
"""

import hashlib
import re
import sys
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/google/fonts/295d98a7a0c17c68f1341eaeea354e7960ea70d3/ofl/"
FONTS = [
    ("NotoSansJP.ttf", BASE + "notosansjp/NotoSansJP%5Bwght%5D.ttf",
     "c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f", "NotoSansJP-Subset.ttf"),
]
ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
EXTRA = "−"  # 差の負の印


def strings_chars() -> set[str]:
    text = (ROOT / "core" / "strings.gd").read_text(encoding="utf-8")
    return set("".join(re.findall(r'"((?:[^"\\\n]|\\.)*)"', text)))


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    chars = set(ASCII) | set(EXTRA) | strings_chars()
    for src_name, url, sha, out_name in FONTS:
        src = ROOT / "tools" / "font_src" / src_name
        out = ROOT / "assets" / "fonts" / out_name
        if not src.exists():
            src.parent.mkdir(parents=True, exist_ok=True)
            print(f"取得: {url}")
            urllib.request.urlretrieve(url, src)
        digest = hashlib.sha256(src.read_bytes()).hexdigest()
        if digest != sha:
            sys.exit(f"{src} の sha256 が違う: {digest}(消して取り直す)")
        font = TTFont(src)
        options = subset.Options()
        options.layout_features = ["*"]
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=[ord(c) for c in chars])
        subsetter.subset(font)
        out.parent.mkdir(parents=True, exist_ok=True)
        font.save(out)
        missing = sorted(c for c in chars if ord(c) not in font.getBestCmap())
        print(f"{out.name}: {src.stat().st_size:,} -> {out.stat().st_size:,} バイト、{len(chars)} 文字")
        if missing:
            print(f"  原本に無い文字: {''.join(missing)}")


if __name__ == "__main__":
    main()
