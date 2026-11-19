# 塔とタコの描画と演出(画面設計書 §3・§9、仕様書 §9.13)。見えている行のマスだけを描く。塔の座標で描き、play が位置をずらす。
# climb.snapshot() と events を読むだけで、ゲームの決まりは持たない(INV-1)。演出の時間は実時間(ms)で数える。
extends Node2D

const B := preload("res://core/balance.gd")
const Grid := preload("res://core/grid.gd")
const Climb := preload("res://core/climb.gd")
const Kit := preload("res://ui/kit.gd")

var climb: RefCounted
var ghost: RefCounted = null  # 影の Climb(無ければ null)
var view_top := 0.0
var now_ms := 0
var draws := 0  # 描いた回数(smoke が読む)

var _arm_at := -100000  # cast_ok の時刻
var _squash_at := -100000
var _squash_axis := Vector2.ZERO  # つぶれる向き(張り付き・着地)
var _rings: Array = []  # [{p, at}]
var _misses: Array = []  # 空振りの腕 [{from, to, kind, at}]
var _miss_circle_at := -100000
var _pieces: Array = []  # 崩れたマスの破片 [{col, row, at}]


func event(e: Dictionary) -> void:
	match e["type"]:
		"cast_ok":
			_arm_at = now_ms
		"stick":
			_squash_at = now_ms
			_squash_axis = Vector2(e["dx"], e["dy"])
			_rings.append({"p": Vector2(e["x"], e["y"]), "at": now_ms})
		"land":
			_squash_at = now_ms
			_squash_axis = Vector2(0, 1)
		"cast_miss":
			_misses.append({"from": Vector2(e["from_x"], e["from_y"]), "to": Vector2(e["x"], e["y"]), "kind": e["result"], "at": now_ms})
			_miss_circle_at = now_ms
		"crumble":
			_pieces.append({"col": e["col"], "row": e["row"], "at": now_ms})


func _draw() -> void:
	if climb == null:
		return
	draws += 1
	var grid: RefCounted = climb.grid
	var t := float(B.TILE)
	var top := view_top
	var bottom := view_top + B.VIEW_H
	# 背景: 区画ごとに少しずつ明るく(下が暗い)
	var tower: RefCounted = climb.tower
	for i in B.SEGMENTS:
		var y0 := float(tower.seg_top_row(i) * B.TILE)
		draw_rect(Rect2(0, y0, B.VIEW_W, B.ROWS * t), Kit.C_BG.lerp(Kit.C_BG_TOP, i / float(B.SEGMENTS)))
	draw_rect(Rect2(0, 0, B.VIEW_W, B.GOAL_ROWS * t), Kit.C_BG_TOP)
	var shake := {}
	for b: Dictionary in climb.snapshot()["brittle"]:
		if not b["gone"]:
			shake[int(b["row"]) * grid.cols + int(b["col"])] = int(b["left"])
	var r0 := maxi(floori(top / t) - 1, 0)
	var r1 := mini(floori(bottom / t) + 1, grid.rows - 1)
	for row in range(r0, r1 + 1):
		for col in grid.cols:
			var k: int = grid.kind(col, row)
			if k == Grid.EMPTY:
				continue
			var rect := Rect2(col * t, row * t, t, t)
			match k:
				Grid.WALL:
					draw_rect(rect, Kit.C_WALL)
					draw_rect(rect.grow(-1), Kit.C_WALL_EDGE, false, 2.0)
					if (row - (B.GOAL_ROWS - 1)) % B.ROWS == 0 and col >= 7 and col <= 10:
						draw_line(rect.position, rect.position + Vector2(t, 0), Kit.C_LEDGE, 2.0)
				Grid.SLICK:
					draw_rect(rect, Kit.C_SLICK)
					var dark := Color(1, 1, 1, 0.75)
					for s: float in [0.2, 0.5, 0.8]:
						draw_line(rect.position + Vector2(s * t - 6, t - 4), rect.position + Vector2(s * t + 6, 4), dark, 1.5, true)
				Grid.SPIKE:
					for h in 2:
						var x0 := rect.position.x + h * t / 2.0
						draw_colored_polygon(PackedVector2Array([Vector2(x0 + 1, rect.end.y), Vector2(x0 + t / 4.0, rect.position.y + 4),
							Vector2(x0 + t / 2.0 - 1, rect.end.y)]), Kit.C_SPIKE)
				Grid.BRITTLE:
					var left: int = shake.get(row * grid.cols + col, -1)
					var off := Vector2.ZERO
					var cracks := 1
					if left >= 0:
						off = Vector2(1.5 * sin(now_ms * 0.09 + col), 0)  # 震える
						cracks = 1 + int(3.0 * (1.0 - left / float(B.CRUMBLE_TICKS)))
					_draw_brittle(rect.grow(-3).get_center() + off, t - 6, cracks)
	for p: Dictionary in _pieces:
		var age := (now_ms - int(p["at"])) / 300.0
		if age >= 1.0:
			continue
		var base := Vector2(int(p["col"]) * t, int(p["row"]) * t)
		for q in 4:
			var o := Vector2((q % 2) * t / 2.0, (q / 2) * t / 2.0)
			var fall := Vector2((q % 2 - 0.5) * 30.0 * age, 160.0 * age * age)
			draw_rect(Rect2(base + o + fall, Vector2(t / 2.0 - 2, t / 2.0 - 2)), Color(Kit.C_BRITTLE, 1.0 - age))
	_draw_fx()
	if ghost != null and not ghost.is_over():
		Kit.draw_tako(self, Vector2(ghost.x, ghost.y), 1.0, 1.0, Color(1, 1, 1, 0.35))
	_draw_tako()


func _draw_brittle(c: Vector2, s: float, cracks: int) -> void:
	var rect := Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s))
	draw_rect(rect, Color(Kit.C_BRITTLE, 0.35))
	# 点線の縁
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for d in 5:
			draw_line(a.lerp(b, d / 5.0), a.lerp(b, (d + 0.55) / 5.0), Kit.C_BRITTLE, 2.0)
	var lines := [[Vector2(-0.3, -0.35), Vector2(0.05, 0.0), Vector2(-0.1, 0.35)], [Vector2(0.05, 0.0), Vector2(0.35, 0.15)],
		[Vector2(0.05, 0.0), Vector2(0.25, -0.35)], [Vector2(-0.1, 0.35), Vector2(-0.35, 0.2)]]
	for i in mini(cracks, lines.size()):
		var pts := PackedVector2Array()
		for v: Vector2 in lines[i]:
			pts.append(c + v * s)
		draw_polyline(pts, Kit.C_BRITTLE, 1.5)


func _draw_fx() -> void:
	for r: Dictionary in _rings:
		var age := (now_ms - int(r["at"])) / 200.0
		if age < 1.0:
			draw_arc(r["p"], 16.0 + 28.0 * age, 0, TAU, 32, Color(Kit.C_SUCKER, 1.0 - age), 3.0, true)
	for m: Dictionary in _misses:
		var age := (now_ms - int(m["at"])) / 200.0
		if age >= 1.0:
			continue
		var reach := 1.0 - absf(age * 2.0 - 1.0)  # 伸びて戻る
		var from: Vector2 = m["from"]
		var to: Vector2 = m["to"]
		draw_line(from, from.lerp(to, reach), Color(Kit.C_TAKO, 0.8), 4.0, true)
		if m["kind"] == "slick":
			for a: Vector2 in [Vector2(8, -6), Vector2(-7, -8), Vector2(2, 9)]:
				draw_line(to, to + a, Color(1, 1, 1, 1.0 - age), 2.0)
		elif m["kind"] == "spike":
			draw_line(to + Vector2(-7, -7), to + Vector2(7, 7), Color(Kit.C_SPIKE, 1.0 - age), 3.0)
			draw_line(to + Vector2(-7, 7), to + Vector2(7, -7), Color(Kit.C_SPIKE, 1.0 - age), 3.0)
	_rings = _rings.filter(func(r: Dictionary) -> bool: return now_ms - int(r["at"]) < 200)
	_misses = _misses.filter(func(m: Dictionary) -> bool: return now_ms - int(m["at"]) < 200)
	_pieces = _pieces.filter(func(p: Dictionary) -> bool: return now_ms - int(p["at"]) < 300)


func _draw_tako() -> void:
	var p := Vector2(climb.x, climb.y)
	var st: int = climb.state
	# 届く範囲の円(空振りの後 0.3 秒は点線)
	var circle := Color(1, 1, 1, 0.15)
	if st != Climb.RESPAWN:
		if now_ms - _miss_circle_at < 300:
			for k in 48:
				if k % 2 == 0:
					draw_arc(p, B.ARM_REACH, TAU * k / 48.0, TAU * (k + 1) / 48.0, 4, circle, 1.0)
		else:
			draw_arc(p, B.ARM_REACH, 0, TAU, 96, circle, 1.0)
	# 腕(飛ぶ間と張り付いている間)
	if st == Climb.FLY or st == Climb.STICK:
		var dest := Vector2(climb.dest_x, climb.dest_y)
		var grow := clampf((now_ms - _arm_at) / 60.0, 0.0, 1.0)
		var tip := p.lerp(dest, grow) if st == Climb.FLY else dest
		if st == Climb.FLY:
			var back := (p - dest).normalized() * 18.0
			draw_line(p + back * 0.9, p + back * 2.2, Color(Kit.C_TAKO, 0.4), 4.0)
		draw_line(p, tip, Kit.C_TAKO, 6.0, true)
		for k in 3:
			draw_circle(p.lerp(tip, (k + 1) / 4.0), 2.5, Kit.C_SUCKER)
	var sx := 1.0
	var sy := 1.0
	var age := (now_ms - _squash_at) / 100.0
	if age < 1.0:
		var amount := 0.2 * (1.0 - age)
		if absf(_squash_axis.y) >= absf(_squash_axis.x):
			sy -= amount
			sx += amount
		else:
			sx -= amount
			sy += amount
	if st == Climb.FALL:
		sy *= 1.15
		sx *= 0.92
	var alpha := 1.0
	if st == Climb.RESPAWN:
		alpha = 0.2 + 0.8 * (1.0 - climb.respawn_left / float(B.RESPAWN_TICKS))
	Kit.draw_tako(self, p, sx, sy, Color(Kit.C_TAKO, alpha))
