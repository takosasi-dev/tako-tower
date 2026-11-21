# 画面の切り替え(S1〜S5)・キー(Esc・R・Enter)・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。
# --auto(ヘッドレスの smoke 用)で、いつもの塔を探した道で登り → 結果 → やり直す → 一時停止 → タイトル まで自動で通す。
extends Node

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Tower := preload("res://core/tower.gd")
const SegStore := preload("res://core/segment_store.gd")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Play := preload("res://ui/play.gd")
const Title := preload("res://ui/title.gd")
const Result := preload("res://ui/result.gd")
const Settings := preload("res://ui/settings.gd")
const Pause := preload("res://ui/pause.gd")
const Backdrop := preload("res://ui/backdrop.gd")

var stage: Control
var store: Store
var segments: Array = []
var data_ok := false
var screen := "title"  # title / play / result / settings
var current: Control = null
var play: Play = null
var pause_view: Pause = null
var settings_view: Settings = null
var settings_from := "title"
var run := {}  # 今の回 { kind, day, date, tower }
var auto := false
var auto_log: Array = []
var _visibility_cb: Variant = null
# ?debug=1(Web)/ --debug: window.ttState に状態を出し、window.ttTap(wx, wy) で塔の中の点を押せる(窓なし Chrome の確かめ用)
var debug := false
var frame_ms: Array = []
var lat_ms: Array = []  # 押してから腕を描いたフレームまで(NFR-2)
var _last_frame := 0
var _arm_drawn := -100000
var _tap_cb: Variant = null
var backdrop: Control
# 画面の切り替わり(v0.3.0。見た目だけ。screen・current・play は今どおりすぐ切り替える)
const ENTER_SEC := 0.26  # 入る: 下から 28 px 浮かんで、少し行き過ぎて戻る(ぷるん)
const ENTER_FADE_SEC := 0.16
const LEAVE_SEC := 0.15  # 出る: 薄くなって消える(押せない)
const PLAY_FADE_SEC := 0.12  # 遊びに入る時は薄い所から出るだけ(押した点がずれないよう動かさない)


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(B.VIEW_W, B.VIEW_H)
	add_child(stage)
	backdrop = Backdrop.new()
	stage.add_child(Kit.place(backdrop, 0, 0, B.VIEW_W, B.VIEW_H))  # 見えている範囲全部を塗る(E-19 の余りも)
	auto = OS.get_cmdline_user_args().has("--auto")
	if auto and FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))  # 自動の通しは記録なしから始める
	store = Store.new()
	var d := SegStore.load_file()
	data_ok = d["ok"]
	segments = d.get("segments", [])
	_apply_settings()
	_watch_visibility()
	debug = _flag("debug")
	get_viewport().size_changed.connect(_fit)
	_fit()
	RenderingServer.frame_post_draw.connect(_after_draw)
	if debug and OS.has_feature("web"):
		_tap_cb = JavaScriptBridge.create_callback(func(a: Array) -> void:
			if play != null:
				play.tap_world(int(a[0]), int(a[1])))
		JavaScriptBridge.get_interface("window").ttTap = _tap_cb
	_show_title()


# 720×1280 を画面の真ん中に置く(stretch の aspect は expand。余りは背景色の下敷きが埋める。E-19)。
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	stage.position = ((vs - Vector2(B.VIEW_W, B.VIEW_H)) / 2.0).floor()


static func _flag(flag: String) -> bool:
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("location.search", true)
		return q is String and q.contains(flag + "=1")
	return OS.get_cmdline_user_args().has("--" + flag)


func _apply_settings() -> void:
	Sfx.set_volume(int(store.settings()["volume"]))
	backdrop.still = calm()


# 点滅を弱める=入 の時は、動きも減らす(切り替わりは短い薄れだけ、題字と光は止める)。
func calm() -> bool:
	return bool(store.settings()["reduce_flash"])


# 前の画面を片付ける。出ていく画面は押せなくし(処理を止める)、薄くしてから消す。
func _clear() -> void:
	get_viewport().gui_release_focus()  # 出ていく画面のボタンにフォーカスを残さない(Enter で 2 回始まらない)
	for n: Node in [pause_view, settings_view]:
		if n != null:
			_leave(n)
	pause_view = null
	settings_view = null
	for c in stage.get_children():
		if c == backdrop or c.has_meta("leaving"):
			continue
		_leave(c)
	current = null
	play = null


func _leave(n: Node) -> void:
	n.set_meta("leaving", true)
	n.process_mode = Node.PROCESS_MODE_DISABLED
	# 処理を止めてもマウスは受けてしまう(一時停止の暗幕が、消えるまでの間の押しを飲んだ)。全部の部品を素通りにする
	for c: Node in [n] + n.find_children("*", "Control", true, false):
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not (n is CanvasItem) or not is_inside_tree():
		n.queue_free()
		return
	var tw := get_tree().create_tween()  # 木に付けた tween(止めた画面に付けると動かない)
	tw.tween_property(n, "modulate:a", 0.0, LEAVE_SEC)
	tw.tween_callback(n.queue_free)


# 入ってくる画面の動き。play は動かさずに薄い所から出す。focus は入った時にフォーカスを置くボタン。
func _enter(c: Control, focus: Control = null, is_play := false) -> void:
	if focus != null:
		Sfx.ui("hush")
		focus.grab_focus.call_deferred()
	if not is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := get_tree().create_tween()
	if is_play or calm():
		tw.tween_property(c, "modulate:a", 1.0, PLAY_FADE_SEC)
		return
	c.position.y = 28.0
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, ENTER_FADE_SEC)
	tw.tween_property(c, "position:y", 0.0, ENTER_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.pressed:
		Sfx.unlock()  # FR-28: 最初の入力の後から鳴らす
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
		return  # 結果の枠の Ctrl+C などは部品に渡す
	key(event.physical_keycode)


# 画面設計書 §8 のキー。Enter は、フォーカスのあるボタンがあればそのボタンに任せる(押すのは 1 回だけ)。
func key(code: int) -> void:
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER
	if enter and get_viewport().gui_get_focus_owner() is Button:
		return
	if settings_view != null:
		if code == KEY_ESCAPE:
			_settings_back()
		return
	match screen:
		"title":
			if enter:
				_on_title("fixed")
		"play":
			if code == KEY_ESCAPE:
				if pause_view != null:
					_on_pause("resume")
				else:
					_pause()
			elif code == KEY_R:
				_start(run)
		"result":
			if (code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_R) and current.can_retry():
				_start(run)


# --- S1 タイトル ---

func _show_title() -> void:
	_clear()
	screen = "title"
	backdrop.lite = false
	var d := _today()
	var t := Title.new()
	t.build(store, d["day"], d["date"], data_ok)
	t.chosen.connect(_on_title)
	stage.add_child(t)
	current = t
	_enter(t, t.first)
	if auto:
		_auto_title.call_deferred()


func _on_title(what: String) -> void:
	if what == "settings":
		_show_settings("title")
		return
	if not data_ok:
		return
	var d := _today()
	var tower: RefCounted = Tower.fixed(segments) if what == "fixed" else Tower.daily(segments, Day.daily_seed(d["day"]))
	_start({"kind": what, "day": d["day"], "date": d["date"], "tower": tower})


# 端末の今日の日付。始めた時の日付で塔を決める(E-17)。
func _today() -> Dictionary:
	var t := Time.get_date_dict_from_system()
	var y := int(t["year"])
	var m := int(t["month"])
	var dd := int(t["day"])
	return {"day": Day.day_index(y, m, dd), "date": Day.date_string(y, m, dd)}


# --- S2 プレイ ---

func _start(r: Dictionary) -> void:
	_clear()
	run = r
	screen = "play"
	backdrop.lite = true
	play = Play.new()
	var st: Dictionary = store.settings()
	play.shake_on = st["shake"]
	play.reduce_flash = st["reduce_flash"]
	stage.add_child(play)
	var tower: RefCounted = r["tower"]
	var best: Variant = store.best(r["kind"], r["day"])
	var splits: Array = []
	if best is Dictionary and best.get("tower") == tower.name and best.has("splits"):
		splits = best["splits"]
	var ghost: Variant = store.ghost(r["kind"], r["day"], tower.name) if st["ghost"] else null
	play.start(tower, ghost, splits)
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_pause)
	current = play
	_enter(play, null, true)
	if auto:
		_auto_play.call_deferred()


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.paused = true
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	stage.add_child(pause_view)
	_enter(pause_view, pause_view.first)


func _on_pause(what: String) -> void:
	match what:
		"resume":
			get_viewport().gui_release_focus()
			_leave(pause_view)
			pause_view = null
			play.paused = false  # 押した tick から再開(待ち時間なし)
		"restart":
			_start(run)
		"settings":
			_show_settings("pause")
		"title":
			_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()  # E-11: 戻っても自動では再開しない


# タブが裏に回ったら一時停止にする。Web では通知が来ないことがあるので、ブラウザにも聞く(RootCall と同じ)。
func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_visibility_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: _pause())
	var doc: Variant = JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _visibility_cb)


# --- S3 結果 ---

func _on_finished(result: Dictionary) -> void:
	var r := run
	var tower: RefCounted = r["tower"]
	var rec := store.record(r["kind"], r["day"], tower.name, result)
	var text := Share.make(r["date"], r["kind"], rec["first_today"], int(result["ticks"]), int(result["moves"]), int(result["misses"]))
	if auto:
		auto_log.append("描いた %d 回 / 区切り「%s」 / 最高との比べ %s" % [play.view_draws(), play.last_split, rec["prev"] != null])
	_clear()
	screen = "result"
	backdrop.lite = false
	var res := Result.new()
	res.build(result, rec, text, calm())
	res.retry.connect(func() -> void: _start(run))
	res.to_title.connect(_show_title)
	stage.add_child(res)
	current = res
	_enter(res)  # フォーカスは「やり直す」が押せるようになった時に置く(result.gd)
	if auto:
		auto_log.append("result %s %s 手 %d ミス %d" % [tower.name, result["ticks"], result["moves"], result["misses"]])
		_auto_result.call_deferred()


# --- S4 設定 ---

func _show_settings(from: String) -> void:
	settings_from = from
	settings_view = Settings.new()
	settings_view.build(store)
	settings_view.back.connect(_settings_back)
	var sea := Backdrop.new()
	sea.still = calm()
	settings_view.add_child(Kit.place(sea, 0, 0, B.VIEW_W, B.VIEW_H))  # 後ろの画面を隠す海(余りまで)
	settings_view.move_child(sea, 0)
	if pause_view != null:
		pause_view.visible = false
	stage.add_child(settings_view)
	_enter(settings_view, settings_view.first)


func _settings_back() -> void:
	_apply_settings()
	get_viewport().gui_release_focus()
	_leave(settings_view)
	settings_view = null
	if settings_from == "pause" and play != null and pause_view != null:
		var st: Dictionary = store.settings()
		play.shake_on = st["shake"]
		play.reduce_flash = st["reduce_flash"]
		pause_view.visible = true
		_enter(pause_view, pause_view.first)
	else:
		_show_title()


# --- デバッグ用の窓口(読むだけ。?debug=1 の時だけ JS に出す) ---

func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0 and frame_ms.size() < 20000:
		frame_ms.append((now - _last_frame) / 1000.0)
	_last_frame = now
	if play != null and play._view != null and play._view._arm_at != _arm_drawn:
		_arm_drawn = play._view._arm_at
		if play.tap_at_us > 0 and lat_ms.size() < 2000:
			lat_ms.append((now - play.tap_at_us) / 1000.0)
	if debug and OS.has_feature("web"):
		JavaScriptBridge.eval("window.ttState=" + JSON.stringify(JSON.stringify(state())), true)
		if frame_ms.size() % 60 == 0:
			JavaScriptBridge.eval("window.ttStats=" + JSON.stringify(JSON.stringify(stats())), true)


func state() -> Dictionary:
	var out := {"screen": screen, "paused": pause_view != null, "settings": settings_view != null, "buttons": {},
		"sfx": Sfx.played, "unlocked": Sfx.unlocked, "save_failed": store.write_failed, "load_failed": store.load_failed}
	var root: Control = settings_view if settings_view != null else (pause_view if pause_view != null else current)
	if root != null:
		for b in root.find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled:
				# ステージの中の座標(gameCss が画面に直す)。入ってくる動きの途中でも、止まった後の位置を出す
				var at := btn.global_position - stage.position - root.position + btn.size / 2
				out["buttons"][String(btn.name)] = [at.x, at.y]
	if play != null:
		var c: RefCounted = play.climb
		out["play"] = {"state": c.state, "x": c.x, "y": c.y, "lock": c.cast_lock, "tick": c.sim_tick, "clock": c.clock,
			"moves": c.moves, "misses": c.misses, "segment": c.checkpoint + 1, "over": c.over, "cam_y": play.cam_y,
			"tower": c.tower.name, "ghost": play.ghost != null, "brittle": c.brittle.size(),
			"gone": c.brittle.values().filter(func(b: Dictionary) -> bool: return b["gone"]).size(), "tap": [play.last_tap.x, play.last_tap.y]}
	return out


func stats() -> Dictionary:
	return {"lat": _pct(lat_ms), "frame": _pct(frame_ms)}


static func _pct(list: Array) -> Dictionary:
	if list.is_empty():
		return {"n": 0}
	var s := list.duplicate()
	s.sort()
	return {"n": s.size(), "p50": s[s.size() / 2], "p95": s[mini(int(ceil(s.size() * 0.95)) - 1, s.size() - 1)], "max": s[-1]}


# --- 自動の通し(--auto。ヘッドレスの smoke だけが使う。tools は書き出しに入らないので load で読む) ---

var _auto_moves: Array = []
var _auto_runs := 0
var _auto_wait := 0  # 道のタップを始めるまでに待つフレーム


func _auto_title() -> void:
	if _auto_runs > 0:
		auto_log.append("title")
		print("SMOKE ", " / ".join(auto_log))
		print("SMOKE DONE")
		get_tree().quit(0)
		return
	_on_title("fixed")


# 1 回目はそのまま登る。2 回目(やり直し)は、一時停止して続け、真下を 1 回押して空振りしてから登る(影・区切りの差・最高との比べを通す)。
func _auto_play() -> void:
	_auto_runs += 1
	auto_log.append("play %s 影 %s" % [run["tower"].name, play.ghost != null])
	var tp: GDScript = load("res://tools/tower_path.gd")
	var r: Dictionary = tp.find(run["tower"], B.CHECK_REACH, preload("res://core/segment_check.gd").dirs())
	_auto_moves = r["path"]
	if _auto_runs == 2:
		_pause()
		auto_log.append("pause %s" % (pause_view != null))
		_on_pause("resume")
		var c: RefCounted = play.climb
		play.tap_world(int(c.x), int(c.y) + 30)
		_auto_wait = 2


func _process(_delta: float) -> void:
	if not auto or play == null or _auto_moves.is_empty() or play.paused:
		return
	if _auto_wait > 0:
		_auto_wait -= 1
		return
	var c: RefCounted = play.climb
	if (c.state == 0 or c.state == 1) and c.cast_lock == 0:  # STAND・STICK で、空振りの待ちが無い
		var tap: Vector2i = _auto_moves.pop_front()
		play.tap_world(tap.x, tap.y)


func _auto_result() -> void:
	await get_tree().create_timer(0.5).timeout
	if _auto_runs >= 2:
		_show_title()
	else:
		key(KEY_R)
