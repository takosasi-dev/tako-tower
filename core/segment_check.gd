# 「解ける」の検査(§9.6 の (c))。区画の上にゴールの段を足した地図で、腕(cast.gd)だけを使って探す。
# 3 つの始める状態のどれからでも、足した段の足場の上面より 16 px 以上、上に張り付けたら通る。テストと tools だけが呼ぶ。
extends RefCounted

const B := preload("res://core/balance.gd")
const Grid := preload("res://core/grid.gd")
const Cast := preload("res://core/cast.gd")
const Store := preload("res://core/segment_store.gd")


# 向き (dx, dy) の一覧。dx と dy は -span〜span の整数((0, 0) を除く)。span 8 で 288 通り。
static func dirs(span: int = B.CHECK_DIR_SPAN) -> Array:
	var out := []
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			if dx != 0 or dy != 0:
				out.append(Vector2i(dx, dy))
	return out


# 区画の rows で探す。{ ok, starts: [{ok, states, best_y, path}], states }。時間は呼ぶ側で測る(core は Time を使わない)。
static func check(seg_rows: Array, reach: int = B.CHECK_REACH, dir_list: Array = [], cap: int = B.CHECK_STATE_CAP) -> Dictionary:
	if dir_list.is_empty():
		dir_list = dirs()
	var grid: RefCounted = Grid.from_rows(Store.goal_rows() + seg_rows)
	var t := B.TILE
	var entry_top := (B.GOAL_ROWS + B.ROWS - 1) * t  # 入口の足場の上面
	var goal_y := (B.GOAL_ROWS - 1) * t - B.CHECK_GOAL_ABOVE  # 足した段の足場の上面より 16 px 上
	var c_col := (seg_rows[30] as String).find("C")
	var starts := [
		Vector2(c_col * t + t / 2.0, entry_top - B.BODY_RADIUS),
		Vector2(B.CHECK_SIDE_X_LEFT, entry_top - B.CHECK_SIDE_ABOVE),
		Vector2(B.CHECK_SIDE_X_RIGHT, entry_top - B.CHECK_SIDE_ABOVE),
	]
	var out := {"ok": true, "starts": [], "states": 0}
	for s: Vector2 in starts:
		var r := search(grid, s, goal_y, reach, dir_list, cap)
		out["starts"].append(r)
		out["states"] += r["states"]
		if not r["ok"]:
			out["ok"] = false
	return out


# 張り付いた位置を 4 px の格子に丸めて見分け、上にある状態から先に広げる(着けるかどうかは広げる順で変わらない。
# 着けない時は全部を広げ切ってから落とす)。goal_y 以下(上)に張り付けたら ok。見つけた状態が cap を超えたら落とす。
# path は始めからゴールまでのタップした点(整数)の列。
static func search(grid: RefCounted, start: Vector2, goal_y: float, reach: int, dir_list: Array, cap: int,
		start_x: float = NAN, start_y: float = NAN) -> Dictionary:
	# 位置は 64 ビットの float で持つ(Vector2 は 32 ビットで、本番の Climb と角をかすめる所で結果が変わる)
	var sx: float = start.x if is_nan(start_x) else start_x
	var sy: float = start.y if is_nan(start_y) else start_y
	var t := B.TILE
	var seen := {_key(sx, sy): 0}
	var px := PackedFloat64Array([sx])
	var py := PackedFloat64Array([sy])
	var parent := PackedInt32Array([-1])
	var taps: Array = [Vector2i.ZERO]
	var buckets := {}  # y を 4 px で丸めた値 → 状態の番号の列
	buckets[_bucket(sy)] = [0]
	var best_y := sy
	while true:
		# 一番上(y が小さい)の状態を取り出す
		var b := -1
		for key: int in buckets:
			if b < 0 or key < b:
				b = key
		if b < 0:
			break
		var list: Array = buckets[b]
		var i: int = list.pop_back()
		if list.is_empty():
			buckets.erase(b)
		var x: float = px[i]
		var y: float = py[i]
		for d: Vector2i in dir_list:
			var wx := roundi(x + d.x * t)
			var wy := roundi(y + d.y * t)
			var r := Cast.cast(grid, x, y, wx, wy, reach)
			if r["result"] != Cast.OK:
				continue
			var ax: float = r["anchor_x"]
			var ay: float = r["anchor_y"]
			var k := _key(ax, ay)
			if seen.has(k):
				continue
			var id := px.size()
			seen[k] = id
			px.append(ax)
			py.append(ay)
			parent.append(i)
			taps.append(Vector2i(wx, wy))
			best_y = minf(best_y, ay)
			if ay <= goal_y:
				return {"ok": true, "states": px.size(), "best_y": best_y, "path": _path(parent, taps, id), "end": Vector2(ax, ay)}
			if px.size() > cap:
				return {"ok": false, "states": px.size(), "best_y": best_y, "path": [], "capped": true}
			var nb := _bucket(ay)
			if not buckets.has(nb):
				buckets[nb] = []
			buckets[nb].append(id)
	return {"ok": false, "states": px.size(), "best_y": best_y, "path": []}


static func _bucket(y: float) -> int:
	return floori(y / B.CAST_STEP)


static func _key(x: float, y: float) -> int:
	return roundi(x / B.CAST_STEP) * 65536 + roundi(y / B.CAST_STEP)


static func _path(parent: PackedInt32Array, taps: Array, i: int) -> Array:
	var out := []
	while i > 0:
		out.push_front(taps[i])
		i = parent[i]
	return out
