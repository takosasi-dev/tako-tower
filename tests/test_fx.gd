# 磨きで足した演出と見た目の分岐(仕様書 §14)。点滅を弱める・揺れを切るへの従い方、ミスとゴールの散る線、
# 張り付いた時の輪の大きさ、結果の表の色、上の表示の下敷き、タイトルの遊び方の絵。演出の時刻は now_ms を自分で入れる。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Save := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Result := preload("res://ui/result.gd")
const View := preload("res://ui/tower_view.gd")


func _main() -> Node:
	if FileAccess.file_exists(Save.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(n: Node) -> void:
	n.get_parent().remove_child(n)
	n.free()


func _play(m: Node) -> Control:
	(m.current.find_child("fixed", true, false) as Button).pressed.emit()
	return m.play


func test_miss_flash_follows_reduce_flash() -> bool:
	var m := _main()
	var p := _play(m)
	p.reduce_flash = false
	p.on_miss(Time.get_ticks_msec())
	p._place_view()
	eq(p._edge.alpha, 0.6, "ミスの赤い縁(ふだん)")
	p.reduce_flash = true
	p.on_miss(Time.get_ticks_msec())
	p._place_view()
	eq(p._edge.alpha, 0.2, "点滅を弱める時は 20%")
	p._flash_until = 0
	p._place_view()
	eq(p._edge.alpha, 0.0, "150 ms の後は消える")
	_done(m)
	return true


# v0.3.1: 遊びの画面の海(光の筋・泡)は点滅を弱めるに従って止まる。壁の縁は外に出た辺だけ(塔の外の列は閉じる)。
func test_play_sea_and_wall_edges() -> bool:
	var m := _main()
	var p := _play(m)
	p.reduce_flash = false
	p._place_view()
	ok(not p._view.still, "ふだんは光と泡が動く")
	p.reduce_flash = true
	p._place_view()
	ok(p._view.still, "点滅を弱める時は止める")
	var g: RefCounted = p.climb.grid
	var seen := {"side": false, "top": false, "inner": false}
	for row in g.rows:
		for col in g.cols:
			if g.kind(col, row) != Grid.WALL:
				continue
			var o := View.open_sides(g, col, row)
			if col == 0:
				ok(o & 4 == 0, "塔の左の外は閉じる")
				seen["side"] = true
			if col == g.cols - 1:
				ok(o & 8 == 0, "塔の右の外は閉じる")
			if g.kind(col, row - 1) == Grid.EMPTY:
				ok(o & 1 != 0, "上が空きなら上の縁")
				seen["top"] = true
			if g.kind(col, row - 1) == Grid.WALL and g.kind(col, row + 1) == Grid.WALL and col > 0 and g.kind(col - 1, row) == Grid.WALL \
					and col < g.cols - 1 and g.kind(col + 1, row) == Grid.WALL:
				eq(o, 0, "囲まれたマスは縁なし")
				seen["inner"] = true
	ok(seen["side"] and seen["top"], "側壁と足場の上の面があった: " + str(seen))
	_done(m)
	return true


func test_miss_shake_follows_setting() -> bool:
	var m := _main()
	var p := _play(m)
	p.shake_on = false
	p.on_miss(Time.get_ticks_msec())
	eq(p._shake_until, 0, "揺れを切ると揺らさない")
	p._place_view()
	eq(p._view.position.x, 0.0, "塔が横にずれない")
	p.shake_on = true
	p.on_miss(Time.get_ticks_msec())
	ok(p._shake_until > Time.get_ticks_msec(), "揺れが入りなら揺らす")
	p._place_view()
	eq(absf(p._view.position.x), B.SHAKE_PX, "4 px ずれる")
	_done(m)
	return true


func test_view_bursts_and_rings() -> bool:
	var m := _main()
	var p := _play(m)
	var v: View = p._view
	v.now_ms = 1000
	v._last_p = Vector2(100, 200)
	v.event({"type": "miss", "reason": "spike"})
	eq(v._bursts.size(), 1, "ミスで散る線")
	eq(v._bursts[0]["p"], Vector2(100, 200), "ミスの前に描いた位置に出す")
	eq(v._bursts[0]["color"], Kit.C_SPIKE, "ミスは赤")
	v.event({"type": "goal", "tick": 10})
	eq(v._bursts[1]["color"], Kit.C_FAST, "ゴールは緑")
	v.event({"type": "stick", "chain": 1, "x": 0.0, "y": 0.0, "dx": 0.0, "dy": -1.0})
	v.event({"type": "stick", "chain": 9, "x": 0.0, "y": 0.0, "dx": 0.0, "dy": -1.0})
	eq(v._rings[0]["grow"], 28.0, "1 回目の輪")
	eq(v._rings[1]["grow"], 52.0, "続けて張り付くと輪が大きい(6 回分で止まる)")
	_done(m)
	return true


func test_hud_band_and_pop() -> bool:
	var m := _main()
	var p := _play(m)
	ok(p.get_children().any(func(n: Node) -> bool: return n.has_method("_draw") and n is Control and n.size.y == 180.0), "上の表示の下敷きがある")
	eq(p.pop(0), 1.3, "出た瞬間は 1.3 倍")
	eq(p.pop(150), 1.0, "150 ms で戻る")
	eq(p.pop(10000), 1.0, "その後は 1 倍")
	_done(m)
	return true


func _result(prev: Variant, splits: Array) -> Control:
	var r := Result.new()
	var rec := {"prev": prev, "new_best": false, "first_today": false, "saved": true}
	r.build({"ticks": int(splits[-1]), "moves": 40, "misses": 0, "splits": splits}, rec, "x")
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	return r


func test_result_worst_row_not_fast_color() -> bool:
	var prev := {"best_ticks": 1000, "splits": [200, 400, 600, 800, 1000]}
	var r := _result(prev, [190, 420, 600, 790, 1010])  # 区画 2 が一番遅れた(+20)
	var band := r.find_child("worst", true, false) as ColorRect
	ok(band != null, "一番遅れた行に帯")
	eq(band.position.y, 376.0 + 54.0 * 2 - 4, "帯は 2 行目")
	var labels := r.find_children("*", "Label", true, false)
	var fast := labels.filter(func(l: Label) -> bool: return l.text == "−0.08")  # 区画 1: 190 − 200 = −10 tick
	ok(not fast.is_empty() and fast[0].get_theme_color("font_color") == Kit.C_FAST, "速い差は緑")
	var slow := labels.filter(func(l: Label) -> bool: return l.text == "+0.25")  # 区画 2: 230 − 200 = +30 tick
	ok(not slow.is_empty() and slow[0].get_theme_color("font_color") == Kit.C_TAKO, "一番遅れた行はタコの色(緑にしない)")
	_done(r)
	var r1 := _result(prev, [190, 390, 590, 780, 980])
	ok(r1.find_child("worst", true, false) == null, "全部速い時は帯なし(遅れた区画が無い)")
	_done(r1)
	var r2 := _result(null, [190, 420, 600, 790, 1010])
	ok(r2.find_child("worst", true, false) == null, "最高が無い時は帯なし")
	var heads := r2.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == S.TABLE_SEG)
	eq(heads[0].position.x + 70.0, 270.0, "最高が無い時は 2 列を真ん中に寄せる")
	_done(r2)
	return true


func test_title_demo_loops() -> bool:
	var m := _main()
	var demo: Control = null
	for ch in m.current.get_children():
		if ch.get("LOOP") != null:
			demo = ch
	ok(demo != null, "タイトルに遊び方の絵")
	for k in 300:
		demo._process(1.0 / 60.0)
	ok(demo.t >= 0.0 and demo.t < demo.LOOP, "4 秒でくり返す")
	_done(m)
	return true


# --- v0.3.0 の UI(画面の切り替わり・フォーカス・Enter・数え上げ・記録更新の祝い・点滅を弱める時の動き) ---

func test_transition_keeps_state_sync_and_leaving_inert() -> bool:
	var m := _main()
	var title: Control = m.current
	eq(String(title.first.name), "fixed", "タイトルはいつもの塔にフォーカスを置く")
	_play(m)
	eq(m.screen, "play", "押した時点で遊びの画面(切り替わりの動きを待たない)")
	ok(title.is_inside_tree() and title.has_meta("leaving"), "出ていくタイトルは薄くなるまで残る")
	eq(title.process_mode, Node.PROCESS_MODE_DISABLED, "出ていく画面は押せない(処理を止める)")
	eq(m.play.position, Vector2.ZERO, "遊びの画面は動かさない(押した点がずれない)")
	ok(not m.state()["buttons"].has("fixed"), "出ていく画面のボタンは状態に出さない")
	eq((title.find_child("fixed", true, false) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "出ていく画面はマウスを素通りにする")
	m.play.pause_requested.emit()
	var pv: Control = m.pause_view
	m._on_pause("resume")
	ok(pv.has_meta("leaving"), "続けると一時停止の板は薄くなって消える")
	eq((pv.get_child(0) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "消えるまでの暗幕が押しを飲まない")
	_done(m)
	return true


func test_enter_motion_follows_reduce_flash() -> bool:
	var m := _main()
	m._show_settings("title")
	eq(m.settings_view.position.y, 28.0, "ふだんは下から浮かんで入る")
	eq(m.settings_view.modulate.a, 0.0, "薄い所から")
	m._settings_back()
	m.store.set_setting("reduce_flash", true)
	m._show_settings("title")
	eq(m.settings_view.position.y, 0.0, "点滅を弱める時は動かさない(薄れだけ)")
	ok(m.calm(), "動きを減らす")
	eq(m.state()["buttons"]["back"], [360.0, 1060.0], "状態のボタンの位置は止まった後の位置")
	_done(m)
	return true


func test_enter_key_defers_to_focused_button() -> bool:
	var m := _main()
	var daily := m.current.find_child("daily", true, false) as Button
	daily.grab_focus()
	ok(m.key(KEY_ENTER), "フォーカスのボタンがあれば、部品にもう一度押させない")
	eq(m.screen, "play", "Enter を押した瞬間にフォーカスのボタン(今日の塔)を押す")
	eq(m.run["kind"], "daily", "いつもの塔でなく、フォーカスの今日の塔")
	m._show_title()
	m.get_viewport().gui_release_focus()
	ok(not m.key(KEY_ENTER), "フォーカスが無い時")
	eq(m.run["kind"], "fixed", "フォーカスが無ければ Enter でいつもの塔")
	m._show_title()
	m._show_settings("title")
	ok(not m.current.visible, "設定の間はタイトルを隠す(フォーカスが逃げない)")
	var leaving: Control = m.current
	m._settings_back()
	eq((leaving.find_child("fixed", true, false) as Control).focus_mode, Control.FOCUS_NONE, "消えていく画面のボタンはフォーカスを取らない")
	_done(m)
	return true


func test_result_count_up_and_focus() -> bool:
	var prev := {"best_ticks": 1000, "splits": [200, 400, 600, 800, 1000]}
	var r := _result(prev, [190, 390, 590, 780, 980])
	eq(r._time.text, "0.00秒", "時間は 0 から数え上げる")
	for k in 20:
		r._process(1.0 / 60.0)
	ok(r.can_retry() and r._retry.has_focus(), "300 ms 後にやり直すが押せて、フォーカスがある")
	ok(r._time.text != "8.16秒", "まだ数えている")
	for k in 30:
		r._process(1.0 / 60.0)
	eq(r._time.text, "8.16秒", "0.6 秒で最後の時間")
	eq(r._badge, null, "最高でない時は札が無い")
	_done(r)
	return true


func test_result_new_best_party_and_calm() -> bool:
	var prev := {"best_ticks": 1000, "splits": [200, 400, 600, 800, 1000]}
	var r := Result.new()
	r.build({"ticks": 980, "moves": 40, "misses": 0, "splits": [190, 390, 590, 780, 980]}, {"prev": prev, "new_best": true, "first_today": false, "saved": true}, "x")
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	ok(r._badge != null and r._party != null, "新しい記録は札と泡で祝う")
	for k in 60:
		r._process(1.0 / 60.0)
	eq(r._badge.size.y, 44.0, "札が出きる")
	_done(r)
	var c := Result.new()
	c.build({"ticks": 980, "moves": 40, "misses": 0, "splits": [190, 390, 590, 780, 980]}, {"prev": prev, "new_best": true, "first_today": false, "saved": true}, "x", true)
	(Engine.get_main_loop() as SceneTree).root.add_child(c)
	c._process(1.0 / 60.0)
	eq(c._time.text, "8.16秒", "点滅を弱める時は数え上げずに最後の時間")
	eq(c._badge.size.y, 44.0, "札もすぐ出す")
	eq(c._party.age, -1.0, "泡ははじけない")
	_done(c)
	var first := Result.new()
	first.build({"ticks": 980, "moves": 40, "misses": 0, "splits": [190, 390, 590, 780, 980]}, {"prev": null, "new_best": true, "first_today": true, "saved": true}, "x")
	ok(first._badge == null, "初めての記録は比べる物が無いので札を出さない")
	first.free()
	return true


func test_ui_sound_quiet_after_press() -> bool:
	Sfx.unlocked = true
	var before: int = Sfx.played
	Sfx.ui("ok")
	Sfx.ui("move")
	eq(Sfx.played, before + 1, "押した直後のフォーカスの移り(次の画面が置く物)では鳴らさない")
	Sfx.ui("hush")
	Sfx.ui("move")
	eq(Sfx.played, before + 1, "画面が置くフォーカスでは鳴らさない")
	Sfx._ui_at = -100000
	Sfx.ui("move")
	eq(Sfx.played, before + 2, "矢印キーでの移りは鳴らす")
	return true
