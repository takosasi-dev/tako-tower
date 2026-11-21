# 画面の後ろの海(タイトル・設定・結果と、遊びの画面の左右の余り)。見えている範囲全部を塗り、泡がゆっくり昇る。
# still(点滅を弱める)では光を揺らさず、泡を半分の速さにする。重くしないよう泡は 22 個、_draw だけ。
extends Control

const Kit := preload("res://ui/kit.gd")

const COUNT := 22
var still := false
var lite := false  # 遊んでいる間: 見えるのは塔の左右の余りだけなので、描き直しを 4 フレームに 1 回にする
var t := 0.0
var _frame := 0
var _seeds: Array = []  # [x の割合, 速さ, 半径, 位相]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := 12345
	for i in COUNT:
		var r: Array = []
		for k in 4:
			s = (s * 1103515245 + 12345) % 2147483648
			r.append(s / 2147483648.0)
		_seeds.append([r[0], 14.0 + 26.0 * r[1], 3.0 + 9.0 * r[2] * r[2], r[3]])


func _process(delta: float) -> void:
	t += delta * (0.5 if still else 1.0)
	_frame += 1
	if not lite or _frame % 4 == 0:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-global_position, get_viewport_rect().size)
	Kit.draw_sea(self, rect, t, still)
	var h := rect.size.y + 80.0
	for b: Array in _seeds:
		var y: float = rect.end.y + 40.0 - fmod(t * float(b[1]) + float(b[3]) * h, h)
		var x: float = rect.position.x + rect.size.x * float(b[0]) + sin(t * 0.9 + float(b[3]) * 6.0) * 10.0
		var fade := clampf((y - rect.position.y) / 200.0, 0.0, 1.0)
		Kit.draw_bubble(self, Vector2(x, y), b[2], 0.55 * fade)
