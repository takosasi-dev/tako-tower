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
	fixed.disabled = not data_ok
	daily.disabled = not data_ok
	fixed.pressed.connect(func() -> void: chosen.emit("fixed"))
	daily.pressed.connect(func() -> void: chosen.emit("daily"))
	settings.pressed.connect(func() -> void: chosen.emit("settings"))
