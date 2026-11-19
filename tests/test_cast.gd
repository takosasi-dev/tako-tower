# 腕の判定(§9.4)のテスト。AC-3・AC-5 と、飛ばしの工夫が 1 回ずつ調べる素直な判定と同じ結果になること。
extends "res://tests/suite.gd"


func _map(edits: Dictionary) -> RefCounted:
	return Grid.from_rows(seg_rows(edits))


# 1 回ずつ全部調べる素直な判定(比べるための物。仕様書 §9.4 をそのまま書いた)。
static func brute(grid: RefCounted, fx: float, fy: float, wx: int, wy: int, reach: int) -> Dictionary:
	var dx := float(wx) - fx
	var dy := float(wy) - fy
	if dx * dx + dy * dy < 64.0:
		return {"result": "near"}
	var l := sqrt(dx * dx + dy * dy)
	var ux := dx / l
	var uy := dy / l
	for k in range(1, reach / 4 + 1):
		var cx := fx + ux * (4.0 * k)
		var cy := fy + uy * (4.0 * k)
		var best := 256.0
		var kind := 0
		var bc := 0
		var br := 0
		for row in range(floori((cy - 16) / 40.0), floori((cy + 16) / 40.0) + 1):
			for col in range(floori((cx - 16) / 40.0), floori((cx + 16) / 40.0) + 1):
				var kk: int = grid.kind(col, row)
				if kk == 0:
					continue
				var nx := clampf(cx, col * 40.0, col * 40.0 + 40.0)
				var ny := clampf(cy, row * 40.0, row * 40.0 + 40.0)
				var d := (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny)
				if d < best:
					best = d
					kind = kk
					bc = col
					br = row
		if kind == 0:
			continue
		if kind == 1 or kind == 4:
			return {"result": "too_close" if k - 1 < 2 else "ok", "anchor_x": fx + ux * (4.0 * (k - 1)),
				"anchor_y": fy + uy * (4.0 * (k - 1)), "tile_col": bc, "tile_row": br}
		return {"result": "slick" if kind == 2 else "spike", "tile_col": bc, "tile_row": br}
	return {"result": "none"}


func test_ac3_up_to_ceiling() -> bool:
	# 体の真上 200 px に # の下面
	var g: Variant = _map({20: "##......####....##"})
	var x := 340.0
	var y := 21 * 40.0 + 200.0
	var r: Variant = Cast.cast(g, x, y, 340, int(y) - 300, B.ARM_REACH)
	eq(r["result"], "ok", "真上の壁")
	var below: float = r["anchor_y"] - 21 * 40.0
	ok(below >= 16.0 and below < 20.0, "張り付き先が下面から 16 以上 20 未満、下: %s" % below)
	return true


func test_ac5_nothing_in_reach() -> bool:
	var g: Variant = _map({})
	var r: Variant = Cast.cast(g, 340.0, 1224.0, 340, 600, B.ARM_REACH)
	eq(r["result"], "none", "320 px 以内に何も無い")
	return true


func test_near_and_too_close() -> bool:
	var g: Variant = _map({})
	eq(Cast.cast(g, 340.0, 1224.0, 343, 1229, B.ARM_REACH)["result"], "near", "8 px 未満は near")
	# 左の側壁の面から 2 px の所で左へ
	eq(Cast.cast(g, 98.0, 1000.0, 0, 1000, B.ARM_REACH)["result"], "too_close", "8 px 未満の張り付き先")
	eq(Cast.cast(g, 106.0, 1000.0, 0, 1000, B.ARM_REACH)["result"], "ok", "8 px 以上なら ok")
	return true


func test_slick_spike_and_outside() -> bool:
	var g: Variant = _map({10: "##...XXXX..^^^^.##"})
	eq(Cast.cast(g, 220.0, 600.0, 220, 300, B.ARM_REACH)["result"], "slick", "X は slick")
	eq(Cast.cast(g, 540.0, 600.0, 540, 300, B.ARM_REACH)["result"], "spike", "^ は spike")
	var g2: Variant = Grid.from_rows(["..................", ".................."])
	eq(Cast.cast(g2, 40.0, 20.0, -200, 20, B.ARM_REACH)["result"], "slick", "左の外はツルツル(E-4)")
	eq(Cast.cast(g2, 680.0, 20.0, 900, 20, B.ARM_REACH)["result"], "slick", "右の外はツルツル")
	eq(Cast.cast(g2, 340.0, 20.0, 340, 400, B.ARM_REACH)["result"], "ok", "下の外は地面")
	return true


func test_first_touch_wins() -> bool:
	# ツルツルの手前に # があれば #、# の手前にツルツルがあれば slick
	var g: Variant = _map({10: "##......####....##", 6: "##......XXXX....##"})
	eq(Cast.cast(g, 380.0, 600.0, 380, 200, B.ARM_REACH)["result"], "ok", "手前の # に張り付く")
	var g2: Variant = _map({10: "##......XXXX....##", 6: "##......####....##"})
	eq(Cast.cast(g2, 380.0, 600.0, 380, 200, B.ARM_REACH)["result"], "slick", "手前の X で空振り")
	return true


func test_fast_cast_equals_brute() -> bool:
	# いろいろな地図・位置・向きで、本番の cast と素直な判定が同じ結果になる
	var maps := [
		_map({5: "##..X.#..^^..B..##", 12: "##.#....##....#.##", 19: "##....XXXX..##..##", 26: "##.^^......##...##"}),
		_map({8: "##.##..##..##..###", 9: "##.#.B.#^.X#....##", 22: "##..............##"}),
	]
	var count := 0
	var diffs := 0
	var seed := 12345
	for g: RefCounted in maps:
		for i in 1500:
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
			var fx := 100.0 + float(seed % 52000) / 100.0
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
			var fy := 40.0 + float(seed % 120000) / 100.0
			if g.hit(fx, fy):
				continue
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
			var wx := int(fx) + (seed % 801) - 400
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
			var wy := int(fy) + (seed % 801) - 400
			var a: Variant = Cast.cast(g, fx, fy, wx, wy, B.ARM_REACH)
			var b: Variant = brute(g, fx, fy, wx, wy, B.ARM_REACH)
			count += 1
			var same: bool = a["result"] == b["result"]
			if same and b.has("tile_col"):
				same = a["tile_col"] == b["tile_col"] and a["tile_row"] == b["tile_row"]
			if same and b.has("anchor_x"):
				same = a["anchor_x"] == b["anchor_x"] and a["anchor_y"] == b["anchor_y"]
			if not same:
				diffs += 1
				if diffs < 4:
					errors.append("違い: from (%s, %s) to (%d, %d): %s / %s" % [fx, fy, wx, wy, a, b])
	ok(count > 2000, "比べた数 %d" % count)
	eq(diffs, 0, "素直な判定との違い")
	return true
