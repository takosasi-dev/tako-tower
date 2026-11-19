# 区画を積んで塔にする(§9.7)。いつもの塔と、種から決まる今日の塔。塔の名前と、区画ごとの高さ・入口の位置を持つ。
# 塔の行は上から: ゴールの段 8 行、区画 5、区画 4 … 区画 1(一番下)。区画の番号 i は下から 0〜4。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")
const Store := preload("res://core/segment_store.gd")

const FIXED_IDS := ["s01", "s03", "s06", "s09", "s10"]

var lines: Array = []  # 上からの文字の行(168 行)
var name: String = ""
var parts: Array = []  # 下から [{id, flip}]


# segs は下から [{id, rows, flip}]。
static func from_list(segs: Array) -> RefCounted:
	var t: RefCounted = load("res://core/tower.gd").new()
	var names := []
	t.lines = Store.goal_rows()
	for i in range(segs.size() - 1, -1, -1):
		var s: Dictionary = segs[i]
		t.lines.append_array(Store.flip_rows(s["rows"]) if s["flip"] else s["rows"])
	for s: Dictionary in segs:
		names.append(s["id"] + ("r" if s["flip"] else ""))
		t.parts.append({"id": s["id"], "flip": s["flip"]})
	t.name = ",".join(names)
	return t


static func _by_id(segments: Array, id: String) -> Dictionary:
	for s: Dictionary in segments:
		if s["id"] == id:
			return s
	return {}


# いつもの塔: 下から s01・s03・s06・s09・s10。反転しない。
static func fixed(segments: Array) -> RefCounted:
	var list := []
	for id: String in FIXED_IDS:
		list.append({"id": id, "rows": _by_id(segments, id)["rows"], "flip": false})
	return from_list(list)


# 今日の塔: 種から区画と反転を引く(§9.7 の順)。
static func daily(segments: Array, seed_value: int) -> RefCounted:
	var rng := Rng.new(seed_value)
	var ids := Store.TIER_IDS
	var picks := []
	var tier4: Array = (ids[4] as Array).duplicate()
	for tier: int in [1, 2, 3]:
		var pool: Array = ids[tier]
		picks.append([pool[rng.next_int(pool.size())], rng.next_int(2) == 1])
	var a: String = tier4[rng.next_int(4)]
	picks.append([a, rng.next_int(2) == 1])
	tier4.erase(a)
	picks.append([tier4[rng.next_int(3)], rng.next_int(2) == 1])
	var list := []
	for p: Array in picks:
		list.append({"id": p[0], "rows": _by_id(segments, p[0])["rows"], "flip": p[1]})
	return from_list(list)


func row_count() -> int:
	return lines.size()


# 区画 i(下から 0〜4)の一番上の行。
func seg_top_row(i: int) -> int:
	return B.GOAL_ROWS + (B.SEGMENTS - 1 - i) * B.ROWS


# 区画 i の下端の y(入口の足場の下面)。
func seg_bottom_y(i: int) -> float:
	return float((seg_top_row(i) + B.ROWS) * B.TILE)


# 区画 i の C に立つ位置(C のマスの中心 x と、その下の足場の上面から 16 px 上)。
func seg_start(i: int) -> Vector2:
	var row := seg_top_row(i) + 30
	var col := (lines[row] as String).find("C")
	return Vector2(col * B.TILE + B.TILE / 2.0, float((row + 1) * B.TILE - B.BODY_RADIUS))


# ゴールの段の足場の上面の y。
func goal_y() -> float:
	return float((B.GOAL_ROWS - 1) * B.TILE)
