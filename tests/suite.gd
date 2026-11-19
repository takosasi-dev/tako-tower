# テストの土台。ok / eq で確かめ、失敗は errors にたまる。地図と塔を組み立てて Climb を進める道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Grid := preload("res://core/grid.gd")
const Cast := preload("res://core/cast.gd")
const Climb := preload("res://core/climb.gd")
const Tower := preload("res://core/tower.gd")
const Store := preload("res://core/segment_store.gd")

const EMPTY_ROW := "##..............##"

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


# 空の区画(つなぎ目の決まりを満たす)。edits は { 行: 文字列 } で行を差し替える。
static func seg_rows(edits: Dictionary = {}) -> Array:
	var rows := []
	for r in B.ROWS:
		rows.append(EMPTY_ROW)
	rows[30] = "##......C.......##"
	rows[31] = Store.ENTRY
	for r: int in edits:
		rows[r] = edits[r]
	return rows


# 区画 5 個を同じ物にした塔(テスト用)。
static func tower_of(rows: Array) -> RefCounted:
	var segs := []
	for i in B.SEGMENTS:
		segs.append({"id": "t%d" % i, "rows": rows, "flip": false})
	return Tower.from_list(segs)


static func run(c: RefCounted, ticks: int) -> Array:
	var ev: Array = []
	for k in ticks:
		c.step()
		ev.append_array(c.events())
	return ev


static func types(ev: Array) -> Array:
	return ev.map(func(e: Dictionary) -> String: return e["type"])


# 体が STICK か STAND になるまで進める(上限 ticks)。
static func settle(c: RefCounted, ticks: int = 2000) -> Array:
	var ev: Array = []
	for k in ticks:
		c.step()
		ev.append_array(c.events())
		if c.state == Climb.STICK or c.state == Climb.STAND or c.is_over():
			break
	return ev


# 入力の記録 [[tick, wx, wy], ...] を流して終わりまで回す。
static func replay(tower: RefCounted, moves: Array, max_ticks: int = 120 * 600) -> RefCounted:
	var c: RefCounted = Climb.new(tower)
	var i := 0
	while not c.is_over() and c.sim_tick < max_ticks:
		while i < moves.size() and int(moves[i][0]) == c.sim_tick:
			c.queue_cast(int(moves[i][1]), int(moves[i][2]))
			i += 1
		c.step()
	return c
