# data/segments.json の読み込みと、区画の形の検査(§9.6 の (a)(b))。左右反転とゴールの段も作る。
# 起動時は (a)(b) だけを行う。「解ける」(c) は segment_check.gd(テストと tools だけ)。
extends RefCounted

const B := preload("res://core/balance.gd")

const PATH := "res://data/segments.json"
const CHARS := ".#X^BC"
# tier ごとに使ってよい文字と、その tier で増えた文字
const TIER_CHARS := {1: ".#C", 2: ".#CX", 3: ".#CX^", 4: ".#CX^B"}
const TIER_NEW := {2: "X", 3: "^", 4: "B"}
const TIER_IDS := {1: ["s01", "s02"], 2: ["s03", "s04", "s05"], 3: ["s06", "s07", "s08"], 4: ["s09", "s10", "s11", "s12"]}

const SIDE := "##..............##"
const ENTRY := "##.....####.....##"


# ゴールの段(つなぎ目の決まりの行 24〜31 と同じ 8 行。C は無し)。
static func goal_rows() -> Array:
	var out := []
	for i in B.GOAL_ROWS - 1:
		out.append(SIDE)
	out.append(ENTRY)
	return out


static func flip_rows(lines: Array) -> Array:
	return lines.map(func(l: String) -> String: return l.reverse())


# { ok, version, segments: [{id, tier, rows}], error }。形 (a) と文字 (b) の検査も行う(E-18)。
static func load_file(path: String = PATH) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {"ok": false, "error": "読めない: " + path}
	return parse(text)


static func parse(text: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return {"ok": false, "error": "JSON ではない"}
	var d: Dictionary = j.data
	var list: Variant = d.get("segments")
	if not (list is Array) or not (d.get("version") is float or d.get("version") is int):
		return {"ok": false, "error": "形が違う"}
	var segs := []
	for s: Variant in list:
		if not (s is Dictionary) or not (s.get("id") is String) or not (s.get("rows") is Array) \
				or not (s.get("tier") is float or s.get("tier") is int):
			return {"ok": false, "error": "区画の形が違う"}
		var rows := []
		for r: Variant in s["rows"]:
			if not (r is String):
				return {"ok": false, "error": "行が文字でない: " + s["id"]}
			rows.append(r)
		var seg := {"id": s["id"], "tier": int(s["tier"]), "rows": rows}
		var errs := shape_errors(seg)
		if not errs.is_empty():
			return {"ok": false, "error": "%s: %s" % [seg["id"], errs[0]]}
		segs.append(seg)
	for tier: int in TIER_IDS:
		for id: String in TIER_IDS[tier]:
			if not segs.any(func(s: Dictionary) -> bool: return s["id"] == id and s["tier"] == tier):
				return {"ok": false, "error": "区画が無い: " + id}
	return {"ok": true, "version": int(d["version"]), "segments": segs, "error": ""}


# (a) 形とつなぎ目、(b) tier の文字。違反を文で返す(空なら通る)。
static func shape_errors(seg: Dictionary) -> Array:
	var errs := []
	var rows: Array = seg["rows"]
	var tier: int = seg["tier"]
	if rows.size() != B.ROWS:
		return ["行の数が %d" % rows.size()]
	var c_count := 0
	var used := {}
	for r in B.ROWS:
		var line: String = rows[r]
		if line.length() != B.COLS:
			errs.append("行 %d の長さが %d" % [r, line.length()])
			continue
		for c in B.COLS:
			var ch := line[c]
			if not CHARS.contains(ch):
				errs.append("行 %d 列 %d に知らない文字 %s" % [r, c, ch])
			used[ch] = true
			if ch == "C":
				c_count += 1
				if r != 30 or (c != 8 and c != 9):
					errs.append("C が行 30 の列 8・9 でない")
			var want := _seam_char(r, c)
			if want != "" and ch != want and not (want == "." and ch == "C" and r == 30):
				errs.append("行 %d 列 %d がつなぎ目の決まり(%s)と違う" % [r, c, want])
	if c_count != 1:
		errs.append("C が %d 個" % c_count)
	if not TIER_CHARS.has(tier):
		errs.append("tier が %d" % tier)
		return errs
	for ch: String in used:
		if not (TIER_CHARS[tier] as String).contains(ch):
			errs.append("tier %d に使えない文字 %s" % [tier, ch])
	if TIER_NEW.has(tier) and not used.has(TIER_NEW[tier]):
		errs.append("tier %d で増えた文字 %s を使っていない" % [tier, TIER_NEW[tier]])
	return errs


# つなぎ目の決まりで決まっている文字。自由なら ""。
static func _seam_char(r: int, c: int) -> String:
	var side := c <= 1 or c >= 16
	if r <= 2:
		return "#" if side else "."
	if r <= 23:
		return ""
	if r <= 27:
		return "#" if side else ""
	if r <= 30:
		return "#" if side else "."
	return "#" if side or (c >= 7 and c <= 10) else "."
