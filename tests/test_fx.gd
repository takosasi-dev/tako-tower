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
