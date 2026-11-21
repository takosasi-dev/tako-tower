# S5 一時停止(画面設計書 §6・§11)。プレイ画面を暗くした上に、丸い角の板を重ねる。続ける・やり直す・設定・タイトルへ。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

var first: Button  # 入った時にフォーカスを置く(続ける)


func build() -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	var dim := ColorRect.new()
	dim.color = Color(Kit.C_BG, 0.78)
	add_child(Kit.place(dim, -2000, -2000, B.VIEW_W + 4000, B.VIEW_H + 4000))  # 横長の画面の左右の余りも暗くする
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(panel, 110, 250, 500, 740))
	add_child(Kit.place(Kit.label(S.PAUSED, 48, Kit.C_TEXT, 800), 0, 290, B.VIEW_W, 70))
	var y := 400.0
	for pair: Array in [["resume", S.BTN_RESUME], ["restart", S.BTN_RETRY], ["settings", S.BTN_SETTINGS], ["title", S.BTN_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 32, "Primary" if pair[0] == "resume" else ""), 180, y, 360, 96)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		if first == null:
			first = b
		y += 124
	add_child(Kit.place(Kit.label(S.PAUSE_KEYS, 22, Kit.C_DIM, 500), 0, 912, B.VIEW_W, 40))
