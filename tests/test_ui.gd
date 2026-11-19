# 画面の流れのテスト(AC-24 のマウスだけの流れ・AC-26・FR-20・FR-25・FR-26・FR-28・E-18)。main.tscn を木に置き、
# マウスのイベントを部品に直接渡し、フレームは _process を呼んで進める。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Save := preload("res://save/save_store.gd")


func _main() -> Node:
	if FileAccess.file_exists(Save.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func click(b: Button) -> void:
	b.pressed.emit()


static func button(root: Node, node_name: String) -> Button:
	return root.find_child(node_name, true, false) as Button


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current != m.play and m.current.has_method("_process"):
			m.current._process(dt)


# プレイ画面を左クリック(画面の座標)。
static func tap(m: Node, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	m.play._gui_input(e)


func _climb_to_goal(m: Node) -> void:
	var tp: GDScript = load("res://tools/tower_path.gd")
	var path: Array = tp.find(m.run["tower"], B.CHECK_REACH, preload("res://core/segment_check.gd").dirs())["path"]
	var guard := 0
	while not path.is_empty() and m.screen == "play" and guard < 20000:
		var st: int = m.play.climb.state
		if st == Climb.STAND or st == Climb.STICK:
			var t: Vector2i = path.pop_front()
			tap(m, Vector2(t.x, t.y - m.play.cam_y))  # 画面の座標で押す
		frames(m, 1)
		guard += 1
	var g2 := 0
	while m.screen == "play" and g2 < 600:
		frames(m, 1)
		g2 += 1


func test_ac24_mouse_only_flow() -> bool:
	var m := _main()
	eq(m.screen, "title", "S1 から始まる")
	ok(m.data_ok, "区画のデータが読める")
	click(button(m.current, "fixed"))
	eq(m.screen, "play", "いつもの塔で S2")
	eq(m.run["tower"].name, "s01,s03,s06,s09,s10", "いつもの塔")
	_climb_to_goal(m)
	eq(m.screen, "result", "ゴールの後 S3")
	var r: Button = button(m.current, "retry")
	ok(r.disabled, "やり直すは入ってすぐは押せない")
	frames(m, 20)
	ok(not r.disabled, "300 ms 後に押せる")
	ok((m.current.share as String).begins_with("TakoTower "), "共有する文字")
	click(r)
	eq(m.screen, "play", "やり直す(1 回の操作。FR-20)")
	eq(m.run["tower"].name, "s01,s03,s06,s09,s10", "同じ塔")
	ok(m.play.ghost != null, "2 回目は影が出る(FR-26)")
	click(button(m.play, "pause"))
	ok(m.pause_view != null, "一時停止")
	click(button(m.pause_view, "title"))
	eq(m.screen, "title", "タイトルへ")
	ok(m.store.best("fixed") != null, "記録が残る")
	_done(m)
	return true


func test_ac26_pause_stops_clock() -> bool:
	var m := _main()
	click(button(m.current, "fixed"))
	var c: RefCounted = m.play.climb
	tap(m, Vector2(100, c.y - m.play.cam_y))  # 左の側壁へ
	frames(m, 30)
	ok(c.clock_running, "時計が動いている")
	m.key(KEY_ESCAPE)
	ok(m.pause_view != null, "Esc で一時停止")
	var clock: int = c.clock
	frames(m, 120)
	eq(c.clock, clock, "一時停止の間は時計が進まない")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "裏に回っても一時停止のまま")
	m.key(KEY_ESCAPE)
	ok(m.pause_view == null, "Esc で続ける")
	frames(m, 10)
	ok(c.clock > clock, "続けると進む")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "タブが裏に回ると一時停止(E-11)")
	clock = c.clock
	frames(m, 60)
	eq(c.clock, clock, "裏の間も進まない")
	click(button(m.pause_view, "restart"))
	eq(m.screen, "play", "一時停止からやり直す(2 回の操作)")
	eq(m.play.climb.clock, 0, "初めから")
	m.key(KEY_R)
	eq(m.play.climb.sim_tick, 0, "R でもやり直す")
	_done(m)
	return true


func test_settings_from_pause_returns() -> bool:
	var m := _main()
	click(button(m.current, "fixed"))
	click(button(m.play, "pause"))
	click(button(m.pause_view, "settings"))
	ok(m.settings_view != null, "設定")
	click(button(m.settings_view, "reduce_flash_true"))
	click(button(m.settings_view, "volume_25"))
	eq(m.store.settings()["volume"], 25, "音量を変えると保存")
	click(button(m.settings_view, "back"))
	ok(m.pause_view != null and m.pause_view.visible, "一時停止へ戻る")
	ok(m.play.reduce_flash, "点滅を弱めるがすぐ効く")
	click(button(m.pause_view, "title"))
	click(button(m.current, "settings"))
	click(button(m.settings_view, "back"))
	eq(m.screen, "title", "タイトルから開いた設定はタイトルへ戻る")
	_done(m)
	return true


func test_daily_entry_and_taps_before_unlock() -> bool:
	var m := _main()
	Sfx.unlocked = false
	click(button(m.current, "daily"))
	eq(m.run["kind"], "daily", "今日の塔")
	var d: Dictionary = m._today()
	eq(m.run["tower"].name, Tower.daily(m.segments, preload("res://core/day_index.gd").daily_seed(d["day"])).name, "種から決まる塔")
	var before: int = Sfx.played
	m.play.climb.queue_cast(100, int(m.play.climb.y))
	frames(m, 30)
	eq(Sfx.played, before, "最初の入力の前は鳴らさない(FR-28)")
	_done(m)
	return true


func test_e18_broken_data_disables_entry() -> bool:
	var m := _main()
	m.data_ok = false
	m._show_title()
	ok(button(m.current, "fixed").disabled, "いつもの塔を押せない")
	ok(button(m.current, "daily").disabled, "今日の塔を押せない")
	_done(m)
	return true
