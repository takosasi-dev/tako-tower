# S1 タイトル(画面設計書 §2・§11)。題字・いつもの塔・今日の塔・設定のボタンと、入口ごとの記録。
# 保存を読めなかった時と、区画のデータが壊れている時は、題の下に 1 行出す(E-13・E-18)。
extends Control

signal chosen(what: String)  # "fixed" / "daily" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://core/time_text.gd")
const Kit := preload("res://ui/kit.gd")

var first: Button  # 画面に入った時にフォーカスを置くボタン


func build(store: RefCounted, day: int, date: String, data_ok: bool) -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	var still: bool = store.settings()["reduce_flash"]
	var logo := Logo.new()
	logo.still = still
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(logo, 0, 110, B.VIEW_W, 300))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_TEXT, 500), 0, 420, B.VIEW_W, 44))
	var note := ""
	if not data_ok:
		note = S.DATA_BROKEN
	elif store.load_failed:
		note = S.LOAD_FAILED
	add_child(Kit.place(Kit.label(note, 22, Kit.C_SPIKE.lerp(Color.WHITE, 0.3), 500), 0, 470, B.VIEW_W, 36))
	var fixed := Kit.place(Kit.button("fixed", S.BTN_FIXED, 40, "Primary"), 80, 530, 560, 120)
	add_child(fixed)
	var best: Variant = store.best("fixed")
	if best is Dictionary:
		add_child(Kit.place(Kit.label(S.REC_BEST % [T.secs(int(best["best_ticks"])), int(best["moves"])], 24, Kit.C_SAND, 500), 0, 664, B.VIEW_W, 36))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.BTN_DAILY, date], 34), 80, 730, 560, 120)
	add_child(daily)
	var d: Variant = store.best("daily", day)
	var rec := S.REC_NONE
	var rec_color := Kit.C_DIM
	if d is Dictionary and d.get("first_ticks") != null:
		rec = S.REC_FIRST % T.secs(int(d["first_ticks"]))
		rec_color = Kit.C_SAND
		if d.has("best_ticks"):
			rec += " / " + S.REC_TODAY_BEST % T.secs(int(d["best_ticks"]))
	add_child(Kit.place(Kit.label(rec, 24, rec_color, 500), 0, 864, B.VIEW_W, 36))
	var settings := Kit.place(Kit.button("settings", S.BTN_SETTINGS, 28), 230, 930, 260, 88)
	add_child(settings)
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 1230, 200, 30))
	var demo := Demo.new()
	demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(demo, 0, 1030, B.VIEW_W, 210))
	fixed.disabled = not data_ok
	daily.disabled = not data_ok
	first = settings if not data_ok else fixed
	fixed.pressed.connect(func() -> void: chosen.emit("fixed"))
	daily.pressed.connect(func() -> void: chosen.emit("daily"))
	settings.pressed.connect(func() -> void: chosen.emit("settings"))


# 題字: 「Tako」(珊瑚)と「Tower」(泡の白)の 2 段。丸い字に濃い縁と水色の影、1 字ずつ少し傾けて波に揺らす。
# 右上に大きなタコ(丸と線だけ)が「Tako」の横に浮かび、腕を「Tower」へ伸ばしている。点滅を弱める時は揺らさない。
class Logo extends Control:
	const LINES := [["Tako", 150, Kit.C_CORAL, 160.0], ["Tower", 118, Kit.C_TEXT, 280.0]]
	var still := false
	var t := 0.0

	func _process(delta: float) -> void:
		if not still:
			t += delta
			queue_redraw()

	func _draw() -> void:
		var f := Kit.display(700)
		var ci := get_canvas_item()
		for li in LINES.size():
			var line: Array = LINES[li]
			var text: String = line[0]
			var fs: int = line[1]
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x - 4.0 * (text.length() - 1)
			var x := (size.x - w) / 2.0 - (36.0 if li == 0 else 0.0)
			for i in text.length():
				var ch := text.unicode_at(i)
				var cw := f.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var bob := 0.0 if still else sin(t * 2.2 - (i + li * 3) * 0.7) * 5.0
				var tilt := -0.06 if (i + li) % 2 == 0 else 0.05
				draw_set_transform(Vector2(x + cw / 2.0, float(line[3]) + bob), tilt)
				var at := Vector2(-cw / 2.0, 0)
				f.draw_char_outline(ci, at + Vector2(0, 10), ch, fs, 22, Kit.C_AQUA_LIP)
				f.draw_char(ci, at + Vector2(0, 10), ch, fs, Kit.C_AQUA_LIP)
				f.draw_char_outline(ci, at, ch, fs, 22, Kit.C_LIP)
				f.draw_char(ci, at, ch, fs, line[2])
				x += cw - 4.0
			draw_set_transform(Vector2.ZERO)
		# 「Tako」の右に浮かぶタコ。腕を「Tower」の上へ伸ばして張り付いている
		var p := Vector2(size.x / 2.0 + 225.0, 70.0 + (0.0 if still else sin(t * 1.6) * 4.0))
		var tip := Vector2(size.x / 2.0 + 150.0, 196.0)  # 「Tower」の r の頭
		draw_line(p, tip, Kit.C_TAKO, 9.0, true)
		for k in 3:
			draw_circle(p.lerp(tip, (k + 1) / 4.0), 3.5, Kit.C_SUCKER)
		draw_line(tip + Vector2(-12, 0), tip + Vector2(12, 0), Kit.C_SUCKER, 6.0, true)
		var wig := 0.0 if still else 2.0 * sin(t * 4.0)
		Kit.draw_tako(self, p, 1.0, 1.0, Kit.C_TAKO, Vector2(-0.7, 0.6), Vector2(0.45, 0.89), wig, not still and fmod(t, 3.3) < 0.12, 34.0)


# 下の余白で、遊び方を 4 秒でくり返し見せる(丸と線だけ):
# 足場に立つ → 壁を押す(輪)→ 腕が伸びて飛ぶ → 張り付く(つぶれと輪)→ もう 1 つ上の壁へ → 消えて初めから。
class Demo extends Control:
	const LOOP := 4.0
	const S0 := Vector2(360, 174)  # 足場の上
	const A := Vector2(176, 92)  # 左の壁の右の面
	const BB := Vector2(544, 44)  # 右の壁の左の面
	# [始まり, 終わり, 元, 先]
	const FLIGHTS := [[0.6, 0.8, S0, A], [1.6, 1.9, A, BB]]
	var t := 0.0

	func _process(delta: float) -> void:
		t = fmod(t + delta, LOOP)
		queue_redraw()

	func _draw() -> void:
		for r: Rect2 in [Rect2(300, 190, 120, 20), Rect2(120, 72, 40, 40), Rect2(560, 24, 40, 40)]:
			Kit.draw_block(self, r, 15)  # 遊びの画面の壁と同じ形(v0.3.1)
		draw_line(Vector2(300, 190), Vector2(420, 190), Kit.C_LEDGE, 2.0)
		var p := S0
		var flying := false
		var dest := S0
		var stuck_at := -10.0
		for f: Array in FLIGHTS:
			if t >= f[0]:
				p = f[3]
				stuck_at = f[1]
			if t >= f[0] and t < f[1]:
				var k: float = (t - f[0]) / (f[1] - f[0])
				p = (f[2] as Vector2).lerp(f[3], k)
				flying = true
				dest = f[3]
			# 押した所の輪(押してから 0.25 秒)
			var since: float = t - f[0]
			if since >= 0.0 and since < 0.25:
				draw_arc(f[3], 8.0 + 16.0 * since / 0.25, 0, TAU, 24, Color(1, 1, 1, 0.6 * (1.0 - since / 0.25)), 2.0, true)
		var alpha := 1.0
		if t > 3.2:
			alpha = clampf(1.0 - (t - 3.2) / 0.3, 0.0, 1.0)
		elif t < 0.3:
			alpha = t / 0.3
		var sx := 1.0
		var sy := 1.0
		var legs := Vector2(0, 1)
		var look := Vector2.ZERO
		if flying:
			legs = (p - dest).normalized()
			look = -legs
			draw_line(p, dest, Color(Kit.C_TAKO, alpha), 5.0, true)
		elif stuck_at > 0.0:
			legs = Vector2(-1, 0) if p == A else Vector2(1, 0)
			look = -legs * 0.5
			var age := (t - stuck_at) / 0.12
			if age < 1.0:
				sx -= 0.2 * (1.0 - age)
				sy += 0.2 * (1.0 - age)
			var ring := (t - stuck_at) / 0.2
			if ring < 1.0:
				draw_arc(p, 16.0 + 28.0 * ring, 0, TAU, 32, Color(Kit.C_SUCKER, 1.0 - ring), 3.0, true)
		Kit.draw_tako(self, p, sx, sy, Color(Kit.C_TAKO, alpha), look, legs, 0.0 if flying else 1.5 * sin(t * 4.0), fmod(t, 2.1) < 0.1)
