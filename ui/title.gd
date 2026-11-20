# S1 タイトル(画面設計書 §2)。いつもの塔・今日の塔・設定のボタンと、入口ごとの記録。
# 保存を読めなかった時と、区画のデータが壊れている時は、題の下に 1 行出す(E-13・E-18)。
extends Control

signal chosen(what: String)  # "fixed" / "daily" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://core/time_text.gd")
const Kit := preload("res://ui/kit.gd")


func build(store: RefCounted, day: int, date: String, data_ok: bool) -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	add_child(Kit.place(Kit.label(S.TITLE, 72, Kit.C_TAKO, 800), 0, 200, B.VIEW_W, 100))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_TEXT, 500), 0, 310, B.VIEW_W, 44))
	var note := ""
	if not data_ok:
		note = S.DATA_BROKEN
	elif store.load_failed:
		note = S.LOAD_FAILED
	add_child(Kit.place(Kit.label(note, 22, Kit.C_SPIKE, 500), 0, 370, B.VIEW_W, 36))
	var fixed := Kit.place(Kit.button("fixed", S.BTN_FIXED, 36), 80, 460, 560, 120)
	add_child(fixed)
	var best: Variant = store.best("fixed")
	if best is Dictionary:
		add_child(Kit.place(Kit.label(S.REC_BEST % [T.secs(int(best["best_ticks"])), int(best["moves"])], 24, Kit.C_DIM), 0, 590, B.VIEW_W, 36))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.BTN_DAILY, date], 36), 80, 670, 560, 120)
	add_child(daily)
	var d: Variant = store.best("daily", day)
	var rec := S.REC_NONE
	if d is Dictionary and d.get("first_ticks") != null:
		rec = S.REC_FIRST % T.secs(int(d["first_ticks"]))
		if d.has("best_ticks"):
			rec += " / " + S.REC_TODAY_BEST % T.secs(int(d["best_ticks"]))
	add_child(Kit.place(Kit.label(rec, 24, Kit.C_DIM), 0, 800, B.VIEW_W, 36))
	var settings := Kit.place(Kit.button("settings", S.BTN_SETTINGS, 30), 220, 900, 280, 88)
	add_child(settings)
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 1230, 200, 30))
	var demo := Demo.new()
	demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(demo, 0, 1010, B.VIEW_W, 210))
	fixed.disabled = not data_ok
	daily.disabled = not data_ok
	fixed.pressed.connect(func() -> void: chosen.emit("fixed"))
	daily.pressed.connect(func() -> void: chosen.emit("daily"))
	settings.pressed.connect(func() -> void: chosen.emit("settings"))


# 下の余白で、遊び方を 4 秒でくり返し見せる(磨きで足した物。丸と線だけ):
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
			draw_rect(r, Kit.C_WALL)
			draw_rect(r.grow(-1), Kit.C_WALL_EDGE, false, 2.0)
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
