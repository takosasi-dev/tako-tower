# S2 プレイ(画面設計書 §3)。押した点を塔の座標に直して Climb へ渡し、たまった時間ぶん step() を回す(1 フレーム 8 tick まで)。
# カメラ(体が上から 60% に来るように追う)・上の表示・区切りの差・音と揺れを受け持つ。決まりは core の Climb にある(INV-1)。
extends Control

signal finished(result: Dictionary)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://core/time_text.gd")
const Climb := preload("res://core/climb.gd")
const Kit := preload("res://ui/kit.gd")
const View := preload("res://ui/tower_view.gd")

var climb: RefCounted
var ghost: RefCounted = null
var ghost_moves: Array = []
var best_splits: Array = []  # 自己ベストの時の区切り(無ければ空)
var paused := false
var shake_on := true
var reduce_flash := false
var cam_y := 0.0
var started_ms := 0
var tap_at_us := 0  # 最後に押した時刻(main が腕を描くまでの時間を測る)
var last_tap := Vector2i(-1, -1)  # 最後に押した塔の中の点(?debug=1 の状態に出す)

var _view: View
var last_split := ""  # 最後に出した区切りの文字(smoke が読む)
var _acc := 0.0
var _ghost_i := 0
var _goal_ms := -1
var _since_goal := 0.0  # ゴールしてからの時間(秒。フレームの delta で数える)
var _shake_until := 0
var _flash_until := 0
var _cp_until := 0
var _clock: Label
var _seg: Label
var _moves: Label
var _cp: Label
var _hint: Label
var _edge: EdgeFlash
var _pips: Pips
var _sent := false
var _moves_shown := -1
var _moves_at := -100000  # 手数が変わった時刻(はねる)


func start(tower: RefCounted, p_ghost: Variant, p_best_splits: Array) -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	climb = Climb.new(tower)
	best_splits = p_best_splits
	if p_ghost is Array and not (p_ghost as Array).is_empty():
		ghost = Climb.new(tower)
		ghost_moves = p_ghost
	_view = View.new()
	_view.climb = climb
	_view.ghost = ghost
	add_child(_view)
	cam_y = _cam_target()
	_hint = Kit.label(S.HINT, 28, Kit.C_TEXT, 700)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Kit.C_BG)
	add_child(Kit.place(_hint, 0, 0, B.VIEW_W, 40))
	var band := HudBand.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(band, 0, 0, B.VIEW_W, HudBand.SOLID + HudBand.FADE))
	# 一時停止: 丸いボタンに縦の棒 2 本(_draw。記号の字を使わない)。フォーカスは取らない(キーは Esc)
	var pause := Kit.place(Kit.button("pause", "", 32), 24, 24, 88, 88)
	pause.focus_mode = Control.FOCUS_NONE
	var bars := PauseBars.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause.add_child(Kit.place(bars, 0, 0, 88, 88))
	pause.pressed.connect(func() -> void: pause_requested.emit())
	add_child(pause)
	# 上の表示: 時計が一番大きい(64)。区画は字と 5 つの丸、手数は右。どれも濃い縁取りで、どんな背景の上でも読める
	_seg = Kit.label("", 24, Kit.C_TEXT, 700)
	_seg.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_seg.add_theme_constant_override("outline_size", 8)
	_seg.add_theme_color_override("font_outline_color", Kit.C_BG)
	add_child(Kit.place(_seg, 130, 28, 150, 40))
	_pips = Pips.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(_pips, 130, 72, 150, 30))
	_clock = Kit.number("0.00", 64, Kit.C_DIM, 12)
	add_child(Kit.place(_clock, 250, 18, 220, 80))
	_moves = Kit.label("", 26, Kit.C_TEXT, 700)
	_moves.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_moves.add_theme_constant_override("outline_size", 8)
	_moves.add_theme_color_override("font_outline_color", Kit.C_BG)
	add_child(Kit.place(_moves, 496, 40, 200, 44))
	_cp = Kit.number("", 32, Kit.C_FAST, 10)
	add_child(Kit.place(_cp, 0, 98, B.VIEW_W, 44))
	_cp.pivot_offset = _cp.size / 2.0
	_clock.pivot_offset = _clock.size / 2.0
	_moves.pivot_offset = Vector2(_moves.size.x, _moves.size.y / 2.0)
	_edge = EdgeFlash.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(_edge, 0, 0, B.VIEW_W, B.VIEW_H))
	started_ms = Time.get_ticks_msec()
	_paint_hud()
	_place_view()


# 押した瞬間の点(FR-2)。タッチはマウスの左ボタンとして届く(project の既定のまま)。一時停止ボタンの上はボタンが受ける。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sfx.unlock()
		tap_screen(event.position)


func tap_screen(p: Vector2) -> void:
	if paused or climb.is_over():
		return
	tap_world(roundi(p.x), roundi(p.y + cam_y))


func tap_world(wx: int, wy: int) -> void:
	tap_at_us = Time.get_ticks_usec()
	last_tap = Vector2i(wx, wy)
	climb.queue_cast(wx, wy)


func is_playing() -> bool:
	return climb != null and not climb.is_over()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	_view.now_ms = now
	if paused:
		_acc = 0.0  # 一時停止の間の時間は捨てる(FR-25)
	elif not climb.is_over():
		_acc += delta * B.TICK_HZ
		var steps := floori(_acc)
		_acc -= steps
		for i in mini(steps, B.MAX_STEPS_PER_FRAME):  # 超えた分は捨てる(E-12)
			_step_once(now)
	elif not _sent:
		_since_goal += delta
		if _since_goal >= B.GOAL_TO_RESULT_SEC:
			_sent = true
			finished.emit(climb.result())
	cam_y = lerpf(cam_y, _cam_target(), B.CAMERA_FOLLOW)
	_place_view()
	_paint_hud()


func _step_once(now: int) -> void:
	climb.step()
	if ghost != null and not ghost.is_over():
		while _ghost_i < ghost_moves.size() and int(ghost_moves[_ghost_i][0]) == ghost.sim_tick:
			ghost.queue_cast(int(ghost_moves[_ghost_i][1]), int(ghost_moves[_ghost_i][2]))
			_ghost_i += 1
		ghost.step()  # 影の events は演出にも音にも使わない(FR-26)
	for e: Dictionary in climb.events():
		_view.event(e)
		match e["type"]:
			"cast_ok":
				Sfx.play("cast")
			"stick":
				Sfx.play("stick", mini(int(e["chain"]) - 1, B.STICK_PITCH_MAX))
				_hint.visible = false
			"cast_miss":
				Sfx.play("cast_miss")
			"land":
				Sfx.play("land")
			"crumble_start":
				Sfx.play("crack")
			"crumble":
				Sfx.play("crumble")
			"miss":
				Sfx.play("miss")
				on_miss(now)
			"checkpoint":
				Sfx.play("checkpoint")
				_show_split(int(e["segment"]) - 2, int(e["tick"]))
			"goal":
				Sfx.play("goal")
				_goal_ms = now


# ミス: 赤い縁 150 ms と、揺れ(設定で揺れを切った時は揺らさない)。
func on_miss(now: int) -> void:
	_flash_until = now + 150
	if shake_on:
		_shake_until = now + int(B.SHAKE_SEC * 1000)


# 区画を越えた時の区切りの時間と、自己ベストの時との差(FR-15)。
func _show_split(index: int, tick: int) -> void:
	call_deferred("_note_split")
	_cp_until = Time.get_ticks_msec() + int(B.CHECKPOINT_SHOW_SEC * 1000)
	if index < best_splits.size():
		var d := tick - int(best_splits[index])
		_cp.text = "%s  %s" % [T.secs(tick), T.diff(d)]
		_cp.add_theme_color_override("font_color", Kit.C_FAST if d < 0 else Kit.C_DIM)
	else:
		_cp.text = T.secs(tick)
		_cp.add_theme_color_override("font_color", Kit.C_TEXT)


func _note_split() -> void:
	last_split = _cp.text


func view_draws() -> int:
	return _view.draws


func _cam_target() -> float:
	var top: float = climb.y - B.VIEW_H * B.CAMERA_BODY_AT
	return clampf(top, 0.0, float(climb.tower.row_count() * B.TILE - B.VIEW_H))


func _place_view() -> void:
	var now := Time.get_ticks_msec()
	var off := Vector2.ZERO
	if now < _shake_until:
		off = Vector2(B.SHAKE_PX if (now / 16) % 2 == 0 else -B.SHAKE_PX, 0)
	_view.position = Vector2(0, -cam_y) + off
	_view.view_top = cam_y
	_view.queue_redraw()
	var hint_y: float = climb.tower.seg_start(0).y - 120.0 - cam_y
	_hint.position.y = hint_y
	var a := 0.0
	if now < _flash_until:
		a = 0.2 if reduce_flash else 0.6  # 点滅を弱める時は 20%(NFR-12)
	if a != _edge.alpha:
		_edge.alpha = a
		_edge.queue_redraw()


func _paint_hud() -> void:
	var snap: Dictionary = climb.snapshot()
	_seg.text = S.HUD_SEGMENT % int(snap["segment"])
	if _pips.segment != int(snap["segment"]):
		_pips.segment = int(snap["segment"])
		_pips.at = Time.get_ticks_msec()
	_moves.text = S.HUD_MOVES % int(snap["moves"])
	if int(snap["moves"]) != _moves_shown:
		if _moves_shown >= 0:
			_moves_at = Time.get_ticks_msec()
		_moves_shown = int(snap["moves"])
	_clock.text = T.secs(int(snap["clock"]))
	var c := Kit.C_FAST if snap["over"] else (Kit.C_TEXT if snap["clock_running"] else Kit.C_DIM)
	_clock.add_theme_color_override("font_color", c)
	var now := Time.get_ticks_msec()
	_cp.visible = now < _cp_until
	# 区切りの差とゴールの時計は、出た瞬間に少し大きく出て 150 ms で戻る(磨きで足した物)
	_cp.scale = Vector2.ONE * pop(now - (_cp_until - int(B.CHECKPOINT_SHOW_SEC * 1000)))
	_clock.scale = Vector2.ONE * (pop(now - _goal_ms) if _goal_ms >= 0 else 1.0)
	# 手数は変わった瞬間に 1.15 倍から 120 ms で戻る(数字の変化の小さなはね。v0.3.0)
	_moves.scale = Vector2.ONE * (1.0 + 0.15 * (1.0 - clampf((now - _moves_at) / 120.0, 0.0, 1.0)))
	_pips.now = now
	_pips.queue_redraw()


static func pop(age_ms: int) -> float:
	return 1.0 + 0.3 * (1.0 - clampf(age_ms / 150.0, 0.0, 1.0))


# 上の表示の下敷き(塔の模様の上でも字が読めるように)。深い海の色で、下の端は波の形(v0.3.0)。その下は薄くぼかす。
class HudBand extends Control:
	const SOLID := 140.0
	const FADE := 40.0

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0)])
		for k in range(24, -1, -1):
			var x := size.x * k / 24.0
			pts.append(Vector2(x, SOLID - 10.0 + 6.0 * sin(k * 0.9)))
		draw_colored_polygon(pts, Color(Kit.C_BG, 0.86))
		for i in 8:
			draw_rect(Rect2(0, SOLID + FADE * i / 8.0 - 4.0, size.x, FADE / 8.0), Color(Kit.C_BG, 0.5 * (1.0 - (i + 1) / 9.0)))


# 一時停止のボタンの印: 丸い端の縦の棒 2 本。
class PauseBars extends Control:
	func _draw() -> void:
		for x: float in [36.0, 52.0]:
			draw_line(Vector2(x, 30), Vector2(x, 54), Kit.C_TEXT, 8.0, true)
			draw_circle(Vector2(x, 30), 4.0, Kit.C_TEXT)
			draw_circle(Vector2(x, 54), 4.0, Kit.C_TEXT)


# 区画の 5 つの丸: 越えた区画は珊瑚で塗り、今いる区画は縁の輪。新しい区画に入った瞬間に丸がはねる。
class Pips extends Control:
	var segment := 1
	var at := -100000
	var now := 0

	func _draw() -> void:
		for i in 5:
			var c := Vector2(10 + i * 27, 14)
			var r := 8.0
			if i == segment - 1:
				r *= 1.0 + 0.5 * (1.0 - clampf((now - at) / 180.0, 0.0, 1.0))
			draw_circle(c, r + 2.5, Kit.C_BG)
			if i < segment - 1:
				draw_circle(c, r, Kit.C_TAKO)
			elif i == segment - 1:
				draw_circle(c, r, Kit.C_SUCKER)
			else:
				draw_arc(c, r - 1.0, 0, TAU, 20, Color(Kit.C_TEXT, 0.55), 2.0, true)


# ミスの時の赤い縁(150 ms)。
class EdgeFlash extends Control:
	var alpha := 0.0

	func _draw() -> void:
		if alpha <= 0.0:
			return
		var c := Color("FF4D4D", alpha)
		var w := 20.0
		draw_rect(Rect2(0, 0, size.x, w), c)
		draw_rect(Rect2(0, size.y - w, size.x, w), c)
		draw_rect(Rect2(0, w, w, size.y - 2 * w), c)
		draw_rect(Rect2(size.x - w, w, w, size.y - 2 * w), c)
