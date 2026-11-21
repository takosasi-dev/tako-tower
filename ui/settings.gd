# S4 設定(画面設計書 §5・§11)。音量(5 段)・画面の揺れ・点滅を弱める・最高の時の影。変えたらすぐ保存する。
# 音量を選ぶと、その音量で張り付く音を 1 回鳴らす。「戻る」か Esc で来た画面へ。
# 今の値は水色の塗りと太い字(選んでいない値は縁だけ)。矢印キーで値の間を動ける。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

var store: RefCounted
var first: Button  # 入った時にフォーカスを置く(今の音量)
var _buttons := {}  # 設定の名前 → { 値: ボタン }


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(B.VIEW_W, B.VIEW_H)
	add_child(Kit.place(Kit.label(S.SETTINGS, 52, Kit.C_TEXT, 800), 0, 140, B.VIEW_W, 76))
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(panel, 36, 246, B.VIEW_W - 72, 734))
	var y := 272.0
	_row(S.VOLUME, y, "volume", B.VOLUMES.map(func(v: int) -> Array: return [v, str(v)]))
	y += 176
	for k: Array in [["shake", S.SHAKE], ["reduce_flash", S.REDUCE_FLASH], ["ghost", S.GHOST]]:
		_row(k[1], y, k[0], [[true, S.ON], [false, S.OFF]])
		y += 176
	var ret := Kit.place(Kit.button("back", S.BACK, 32, "Primary"), 220, 1012, 280, 96)
	ret.pressed.connect(func() -> void: back.emit())
	add_child(ret)
	add_child(Kit.place(Kit.label(S.SETTINGS_KEYS, 22, Kit.C_DIM, 500), 0, 1130, B.VIEW_W, 40))
	_paint()
	first = _buttons["volume"].get(int(store.settings()["volume"]), ret)


# 見出しの下に、選べる値のボタンを横に並べる。
func _row(title: String, y: float, key: String, values: Array) -> void:
	var l := Kit.label(title, 28, Kit.C_TEXT, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, 68, y, 584, 40))
	_buttons[key] = {}
	var w := (584.0 - 12.0 * (values.size() - 1)) / values.size()
	for i in values.size():
		var v: Variant = values[i][0]
		var b := Kit.place(Kit.button("%s_%s" % [key, str(v)], values[i][1], 28, "Chip"), 68 + i * (w + 12), y + 52, w, 88)
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
