# 第三者の素材

同梱している第三者の素材は、次の字体 2 つだけです。効果音は `tools/gen_sfx.py` で合成した自作の物です。

## Noto Sans JP

- ファイル: `assets/fonts/NotoSansJP-Subset.ttf`(原本を、画面に出す文字だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/notosansjp の `NotoSansJP[wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_NotoSansJP.txt`](assets/fonts/OFL_NotoSansJP.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'

## Fredoka

- ファイル: `assets/fonts/Fredoka-Subset.ttf`(題字と数字に使う。原本を数字・記号と題字の字の 25 字に絞り、幅の軸を 100 に固定した物。`tools/subset_font.py` で作る。v0.3.0 で足した)
- 原本: https://github.com/google/fonts/tree/main/ofl/fredoka の `Fredoka[wdth,wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `2ba02e68b152868aef9ba28e24b3648c7d457fe6f25c761f2c2c53fb61a73fc8`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_Fredoka.txt`](assets/fonts/OFL_Fredoka.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2016 The Fredoka Project Authors (https://github.com/hafontia/Fredoka-One)

## 効果音

- ファイル: `assets/sfx/*.wav`(9 個)
- 出どころ: `tools/gen_sfx.py` で合成した自作の音。第三者の素材は使っていない。ライセンスはリポジトリと同じ MIT。
