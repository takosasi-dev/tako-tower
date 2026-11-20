# S4 設定(画面設計書 §5)。音量(5 段)・画面の揺れ・点滅を弱める・最高の時の影。変えたらすぐ保存する。
# 音量を選ぶと、その音量で張り付く音を 1 回鳴らす。「戻る」で来た画面へ。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

var store: RefCounted
var _buttons := {}  # 設定の名前 → { 値: ボタン }


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(B.VIEW_W, B.VIEW_H)
	add_child(Kit.place(Kit.label(S.SETTINGS, 48, Kit.C_TEXT, 700), 0, 150, B.VIEW_W, 70))
	var y := 280.0
	_row(S.VOLUME, y, "volume", B.VOLUMES.map(func(v: int) -> Array: return [v, str(v)]))
	y += 176
	for k: Array in [["shake", S.SHAKE], ["reduce_flash", S.REDUCE_FLASH], ["ghost", S.GHOST]]:
		_row(k[1], y, k[0], [[true, S.ON], [false, S.OFF]])
		y += 176
	var ret := Kit.place(Kit.button("back", S.BACK, 32), 220, y + 24, 280, 88)
	ret.pressed.connect(func() -> void: back.emit())
	add_child(ret)
	_paint()


# 見出しの下に、選べる値のボタンを横に並べる。
func _row(title: String, y: float, key: String, values: Array) -> void:
	var l := Kit.label(title, 28, Kit.C_TEXT, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, 60, y, 600, 40))
	_buttons[key] = {}
	var w := (600.0 - 12.0 * (values.size() - 1)) / values.size()
	for i in values.size():
		var v: Variant = values[i][0]
		var b := Kit.place(Kit.button("%s_%s" % [key, str(v)], values[i][1], 28), 60 + i * (w + 12), y + 48, w, 88)
		b.pressed.connect(func() -> void: _pick(key, v))
		add_child(b)
		_buttons[key][v] = b


func _pick(key: String, v: Variant) -> void:
	store.set_setting(key, v)
	if key == "volume":
		Sfx.set_volume(int(v))
		Sfx.play("stick")
	_paint()


func _paint() -> void:
	var st: Dictionary = store.settings()
	for key: String in _buttons:
		for v: Variant in _buttons[key]:
			Kit.set_selected(_buttons[key][v], st[key] == v)
