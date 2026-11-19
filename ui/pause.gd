# S5 一時停止(画面設計書 §6)。プレイ画面を暗くした上に重ねる。続ける・やり直す・設定・タイトルへ。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")


func build() -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	add_child(Kit.place(dim, 0, 0, B.VIEW_W, B.VIEW_H))
	add_child(Kit.place(Kit.label(S.PAUSED, 48, Kit.C_TEXT, 700), 0, 300, B.VIEW_W, 70))
	var y := 430.0
	for pair: Array in [["resume", S.BTN_RESUME], ["restart", S.BTN_RETRY], ["settings", S.BTN_SETTINGS], ["title", S.BTN_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 32), 180, y, 360, 96)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		y += 120
