# 1 回のプレイの全状態と step()(§9.3・§9.5)。腕・飛ぶ・落ちる・立つ・もろい壁・ミス・区切り・ゴールの決まりはここだけにある(INV-1)。
# 入力は塔の中の整数の点だけ(INV-6)。1 tick = 1/120 秒。腕の判定は cast.gd を呼ぶ(INV-4)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Grid := preload("res://core/grid.gd")
const Cast := preload("res://core/cast.gd")

const STAND := 0
const STICK := 1
const FLY := 2
const FALL := 3
const RESPAWN := 4

var tower: RefCounted
var grid: RefCounted
var x: float = 0.0
var y: float = 0.0
var vy: float = 0.0
var state: int = STAND
var sim_tick: int = 0
var clock: int = 0
var clock_running := false
var cast_lock: int = 0
var respawn_left: int = 0
var moves: int = 0
var misses: int = 0
var checkpoint: int = 0  # 最後に越えた区画(下から 0〜4)
var splits: Array = []
var input_log: Array = []  # 入力の記録 [sim_tick, wx, wy]
var over := false

# 飛ぶ: 行き先・向き・残りの距離・張り付くマス
var dest_x: float = 0.0
var dest_y: float = 0.0
var dir_x: float = 0.0
var dir_y: float = 0.0
var fly_left: float = 0.0
var tile_col: int = 0  # 張り付く(張り付いた)マス
var tile_row: int = 0
var last_stick_tick: int = -1000000
var chain: int = 0
# もろい壁: マスの番号 → { left, gone }
var brittle: Dictionary = {}
var restores: int = 0  # もろい壁が戻った回数
var _restores_at_cast: int = 0

var _has_cast := false
var _cast_x: int = 0
var _cast_y: int = 0
var _events: Array = []


func _init(p_tower: RefCounted) -> void:
	tower = p_tower
	grid = Grid.from_rows(tower.lines)
	var s: Vector2 = tower.seg_start(0)
	x = s.x
	y = s.y


# 塔の中の点へ腕を出す指示。次の step で使う。RESPAWN の間・空振りの待ちの間・終わった後は捨てる(FR-5・FR-6)。
func queue_cast(wx: int, wy: int) -> void:
	if over or state == RESPAWN or cast_lock > 0:
		return
	_has_cast = true
	_cast_x = wx
	_cast_y = wy


func events() -> Array:
	return _events


func is_over() -> bool:
	return over


func step() -> void:
	_events = []
	if over:
		return
	if state == RESPAWN:
		_has_cast = false
		respawn_left -= 1
		if respawn_left <= 0:
			state = STAND
	else:
		_do_cast()
		_move()
		_tick_brittle()
		_check_miss()
		_check_progress()
	if cast_lock > 0:
		cast_lock -= 1
	if clock_running:
		clock += 1
	sim_tick += 1


func _do_cast() -> void:
	if not _has_cast:
		return
	_has_cast = false
	if cast_lock > 0:
		return
	var r := Cast.cast(grid, x, y, _cast_x, _cast_y, B.ARM_REACH)
	var res: String = r["result"]
	if res == Cast.NEAR:
		return
	moves += 1
	input_log.append([sim_tick, _cast_x, _cast_y])
	if res == Cast.OK:
		state = FLY
		vy = 0.0
		dest_x = r["anchor_x"]
		dest_y = r["anchor_y"]
		tile_col = r["tile_col"]
		tile_row = r["tile_row"]
		var dx := dest_x - x
		var dy := dest_y - y
		fly_left = sqrt(dx * dx + dy * dy)
		dir_x = dx / fly_left
		dir_y = dy / fly_left
		_restores_at_cast = restores
		if not clock_running:
			clock_running = true
		_events.append({"type": "cast_ok", "x": dest_x, "y": dest_y})
	else:
		cast_lock = B.CAST_LOCK_TICKS
		_events.append({"type": "cast_miss", "result": res, "x": r["anchor_x"], "y": r["anchor_y"],
			"from_x": x, "from_y": y})


func _move() -> void:
	match state:
		FLY:
			var v := float(B.FLY_SPEED) / B.TICK_HZ
			if fly_left <= v:
				x = dest_x
				y = dest_y
				var k: int = grid.kind(tile_col, tile_row)
				if k == Grid.WALL or k == Grid.BRITTLE:
					_stick()
				else:
					_fall()  # E-7
				return
			var nx := x + dir_x * v
			var ny := y + dir_y * v
			fly_left -= v
			# E-6: 腕を出した後にもろい壁が戻った時だけ重なりを見る(腕は 4 px 刻みで道を確かめ済み。
			# 10 px 刻みで角をかすめた所を拾って、腕と違う結果にしないため)
			if restores != _restores_at_cast and grid.hit(nx, ny):
				var k: int = grid.hit_kind
				if k == Grid.WALL or k == Grid.BRITTLE:
					tile_col = grid.hit_col
					tile_row = grid.hit_row
					_stick()
				elif k == Grid.SLICK:
					_fall()
				else:
					_miss("spike")
				return
			x = nx
			y = ny
		FALL:
			vy = minf(vy + float(B.GRAVITY) / B.TICK_HZ / B.TICK_HZ, float(B.FALL_MAX) / B.TICK_HZ)
			y += vy
			if grid.hit(x, y):
				if grid.hit_kind == Grid.SPIKE:
					_miss("spike")
					return
				tile_col = grid.hit_col
				tile_row = grid.hit_row
				y = float(tile_row * B.TILE - B.BODY_RADIUS)
				vy = 0.0
				state = STAND
				_events.append({"type": "land", "x": x, "y": y})
		STAND:
			if grid.kind_at(x, y + B.STAND_PROBE) == Grid.EMPTY:
				_fall()
		STICK:
			if grid.kind(tile_col, tile_row) == Grid.EMPTY:
				_fall()


func _stick() -> void:
	state = STICK
	vy = 0.0
	chain = chain + 1 if sim_tick - last_stick_tick <= B.STICK_CHAIN_TICKS else 1
	last_stick_tick = sim_tick
	_events.append({"type": "stick", "chain": chain, "x": x, "y": y, "dx": dir_x, "dy": dir_y})


func _fall() -> void:
	state = FALL
	vy = 0.0


# もろい壁: 数え始め・崩れる・戻る。足場や張り付き先が消えたら FALL。
@warning_ignore("integer_division")
func _tick_brittle() -> void:
	for idx: int in brittle.keys():
		var b: Dictionary = brittle[idx]
		var col: int = idx % grid.cols
		var row: int = idx / grid.cols
		b["left"] -= 1
		if b["left"] > 0:
			continue
		if not b["gone"]:
			b["gone"] = true
			b["left"] = B.CRUMBLE_BACK_TICKS
			grid.set_kind(col, row, Grid.EMPTY)
			_events.append({"type": "crumble", "col": col, "row": row})
		elif not grid.overlaps_tile(x, y, col, row):
			grid.set_kind(col, row, Grid.BRITTLE)
			brittle.erase(idx)
			restores += 1
		else:
			b["left"] = 0  # 重ならなくなった tick に戻る
	if state == STICK and grid.kind(tile_col, tile_row) == Grid.EMPTY:
		_fall()
	elif state == STAND and grid.kind_at(x, y + B.STAND_PROBE) == Grid.EMPTY:
		_fall()
	var touch := Vector2i(-1, -1)
	if state == STICK:
		touch = Vector2i(tile_col, tile_row)
	elif state == STAND:
		touch = Vector2i(floori(x / B.TILE), floori((y + B.STAND_PROBE) / B.TILE))
	if touch.x >= 0 and grid.kind(touch.x, touch.y) == Grid.BRITTLE:
		var idx: int = touch.y * grid.cols + touch.x
		if not brittle.has(idx):
			brittle[idx] = {"left": B.CRUMBLE_TICKS, "gone": false}  # 84 tick 後に崩れる
			_events.append({"type": "crumble_start", "col": touch.x, "row": touch.y})


func _check_miss() -> void:
	if state == RESPAWN:
		return
	if _touches_spike():
		_miss("spike")
	elif state == FALL and y >= tower.seg_bottom_y(checkpoint) + B.FALL_MISS_DEPTH:
		_miss("fall")


func _touches_spike() -> bool:
	var r := float(B.BODY_RADIUS)
	for row in range(floori((y - r) / B.TILE), floori((y + r) / B.TILE) + 1):
		for col in range(floori((x - r) / B.TILE), floori((x + r) / B.TILE) + 1):
			if grid.kind(col, row) == Grid.SPIKE and grid.overlaps_tile(x, y, col, row):
				return true
	return false


func _miss(reason: String) -> void:
	misses += 1
	state = RESPAWN
	respawn_left = B.RESPAWN_TICKS
	vy = 0.0
	_has_cast = false
	var s: Vector2 = tower.seg_start(checkpoint)
	x = s.x
	y = s.y
	_events.append({"type": "miss", "reason": reason})


func _check_progress() -> void:
	if state == RESPAWN:
		return
	while checkpoint < B.SEGMENTS - 1 and y < tower.seg_bottom_y(checkpoint + 1):
		checkpoint += 1
		splits.append(clock)
		_events.append({"type": "checkpoint", "segment": checkpoint + 1, "tick": clock})
	if y < tower.goal_y():
		over = true
		clock_running = false
		splits.append(clock)
		_events.append({"type": "goal", "tick": clock})


@warning_ignore("integer_division")
func snapshot() -> Dictionary:
	var crumbling := []
	for idx: int in brittle:
		var b: Dictionary = brittle[idx]
		crumbling.append({"col": idx % grid.cols, "row": idx / grid.cols, "left": b["left"], "gone": b["gone"]})
	return {"x": x, "y": y, "state": state, "dest_x": dest_x, "dest_y": dest_y, "clock": clock,
		"clock_running": clock_running, "moves": moves, "misses": misses, "segment": checkpoint + 1,
		"cast_lock": cast_lock, "respawn_left": respawn_left, "brittle": crumbling, "over": over}


func result() -> Dictionary:
	return {"ticks": clock, "moves": moves, "misses": misses, "splits": splits.duplicate(), "log": input_log.duplicate(true),
		"tower": tower.name}
