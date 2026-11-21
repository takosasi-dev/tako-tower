# S3 結果(画面設計書 §4・§11)。時間・最高との差・手数とミス・区画の表・やり直す・共有する文字の枠・コピー・タイトルへ。
# やり直すは 300 ms 後から押せ、押せるようになった時にフォーカスを置く。コピーは clipboard_set を試し、選べる枠も常に出す(E-16)。
# 時間は 0 から数え上げ(0.6 秒)、自己最高の時は「新しい記録」の札と泡で祝う。点滅を弱める時はどちらも動かさず最後の形で出す。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://core/time_text.gd")
const Kit := preload("res://ui/kit.gd")

const COUNT_SEC := 0.6  # 時間の数え上げ
const BADGE_AT := 0.6  # 新しい記録の札が出る時

var share := ""
var shown_at := 0
var calm := false  # 点滅を弱める: 数え上げ・祝いの動きを省く
var _age := 0.0  # 画面に入ってからの時間(秒)
var _ticks := 0
var _retry: Button
var _copied: Label
var _toast: Control
var _toast_at := -1.0
var _time: Label
var _diff: Label = null
var _diff_new := false
var _badge: Control = null
var _party: Party = null
var _menu: PopupMenu


# rec は save_store.record() の戻り値。prev は前の最高の記録(無ければ null)。
func build(result: Dictionary, rec: Dictionary, share_text: String, p_calm := false) -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	share = share_text
	calm = p_calm
	shown_at = Time.get_ticks_msec()
	_ticks = int(result["ticks"])
	add_child(Kit.place(Kit.label(S.RESULT_TITLE, 40, Kit.C_AQUA, 800), 0, 50, B.VIEW_W, 56))
	_diff_new = rec["new_best"] and rec["prev"] is Dictionary
	if _diff_new:
		_party = Party.new()
		_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(Kit.place(_party, 0, 0, B.VIEW_W, 360))
	_time = Kit.number(_time_text(0 if not calm else _ticks), 112, Kit.C_TEXT, 16)
	add_child(Kit.place(_time, 0, 104, B.VIEW_W, 140))
	_time.pivot_offset = _time.size / 2.0
	var prev: Variant = rec["prev"]
	if prev is Dictionary:
		var d := _ticks - int(prev["best_ticks"])
		var text := S.DIFF_NEW % T.secs(-d) if rec["new_best"] else S.DIFF_BEHIND % T.secs(d)
		_diff = Kit.label(text, 28, Kit.C_FAST if rec["new_best"] else Kit.C_DIM, 700)
		add_child(Kit.place(_diff, 0, 248, B.VIEW_W, 40))
		_diff.pivot_offset = _diff.size / 2.0
	if _diff_new:
		_badge = Badge.new()
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge.rotation = -0.14  # 時間の右上に貼った札
		add_child(Kit.place(_badge, 474, 86, 200, 0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 80)
	row.add_child(Kit.number(S.RESULT_MOVES % int(result["moves"]), 34, Kit.C_TEXT))
	row.add_child(Kit.number(S.RESULT_MISSES % int(result["misses"]), 34, Kit.C_TEXT))
	add_child(Kit.place(row, 0, 296, B.VIEW_W, 50))
	_table(result, prev)
	_retry = Kit.place(Kit.button("retry", S.BTN_RETRY, 40, "Primary"), 80, 716, 560, 120)
	_retry.disabled = true
	add_child(_retry)
	add_child(Kit.place(Kit.label(S.RESULT_KEYS, 20, Kit.C_DIM, 500), 0, 848, B.VIEW_W, 28))
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	# 右クリックの品書きは Godot の英語の物でなく、日本語の 2 つだけ(コピー・全部選ぶ)
	box.context_menu_enabled = false
	box.focus_mode = Control.FOCUS_CLICK
	add_child(Kit.place(box, 60, 884, 600, 130))
	_menu = PopupMenu.new()
	_menu.name = "share_menu"
	_menu.add_item(S.BTN_COPY, 0)
	_menu.add_item(S.MENU_SELECT_ALL, 1)
	_menu.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			DisplayServer.clipboard_set(box.get_selected_text() if box.has_selection() else share)
		else:
			box.grab_focus()
			box.select_all())
	add_child(_menu)
	box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			_menu.position = Vector2i(box.get_screen_transform() * e.position)  # TextEdit の品書きと同じ置き方
			_menu.reset_size()
			_menu.popup())
	var copy := Kit.place(Kit.button("copy", S.BTN_COPY, 30), 60, 1028, 280, 88)
	var title := Kit.place(Kit.button("title", S.BTN_TITLE, 30), 380, 1028, 280, 88)
	add_child(copy)
	add_child(title)
	_toast = Panel.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(Kit.place(_toast, 60, 1134, 600, 48))
	_toast.pivot_offset = _toast.size / 2.0
	_copied = Kit.label("", 22, Kit.C_TEXT, 500)
	_toast.add_child(Kit.place(_copied, 0, 0, 600, 48))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 22, Kit.C_SPIKE.lerp(Color.WHITE, 0.3), 500), 0, 1196, B.VIEW_W, 36))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())


func _time_text(ticks: int) -> String:
	return S.RESULT_TIME % T.secs(ticks)


# 区画の表: 今回・最高の時・差。一番遅れた区画の行を明るい色にする。最高が無い時は「今回」の列だけ。
func _table(result: Dictionary, prev: Variant) -> void:
	var now: Array = T.lap_ticks(result["splits"])
	var best: Array = []
	if prev is Dictionary and (prev["splits"] as Array).size() == B.SEGMENTS:
		best = T.lap_ticks(prev["splits"])
	var worst := -1
	if not best.is_empty():
		var most: int = 0  # 遅れた区画(差がプラス)だけを目立たせる。全部速ければ帯なし(磨きで決めた解釈)
		for i in now.size():
			if int(now[i]) - int(best[i]) > most:
				most = int(now[i]) - int(best[i])
				worst = i
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(card, 40, 362, B.VIEW_W - 80, 338))
	var cols := [S.TABLE_SEG, S.TABLE_NOW] + ([S.TABLE_BEST, S.TABLE_DIFF] if not best.is_empty() else [])
	# 列の中心。最高が無い時は 2 列を真ん中に寄せる
	var xs := [110.0, 270.0, 430.0, 590.0] if not best.is_empty() else [270.0, 450.0]
	var y := 376.0
	for c in cols.size():
		add_child(Kit.place(Kit.label(cols[c], 22, Kit.C_DIM, 700), xs[c] - 70, y, 140, 36))
	for i in now.size():
		y += 54
		# 一番遅れた区画は、タコの色の帯と字で目立たせる(速い色の緑は使わない)。字も太くするので色だけに頼らない
		if i == worst:
			var band := ColorRect.new()
			band.color = Color("4A2C36")  # 珊瑚を沈めた色(海の青緑の上で灰色に濁らない)
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.name = "worst"
			add_child(Kit.place(band, 48, y - 4, B.VIEW_W - 96, 48))
			var mark := ColorRect.new()  # 左の端の珊瑚の印(帯の色だけに頼らない)
			mark.color = Kit.C_TAKO
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.add_child(Kit.place(mark, 0, 0, 6, 48))
		var cells := [str(i + 1), T.secs(int(now[i]))]
		if not best.is_empty():
			cells += [T.secs(int(best[i])), T.diff(int(now[i]) - int(best[i]))]
		for c in cells.size():
			var color := Kit.C_TAKO if i == worst else Kit.C_TEXT
			if c == 3 and i != worst:
				color = Kit.C_FAST if int(now[i]) < int(best[i]) else Kit.C_DIM  # 差: 速い・遅い(画面設計書 §9)
			var cell := Kit.number(cells[c], 26, color)
			if i == worst:
				cell.add_theme_font_override("font", Kit.display(700))
			add_child(Kit.place(cell, xs[c] - 70, y, 140, 40))


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED
	_toast.visible = true
	_toast_at = _age


func _process(delta: float) -> void:
	_age += delta
	if _retry.disabled and _age >= B.RESULT_INPUT_DELAY_SEC:
		_retry.disabled = false
		Kit.ui_sound("hush")
		_retry.grab_focus()  # 「やり直す」に最初からフォーカス(Enter・Space でも押せる)
	if calm:
		_time.text = _time_text(_ticks)
		if _badge != null:
			_badge.size.y = 44.0
		if _diff != null:
			_diff.modulate.a = 1.0
	else:
		# 時間は 0 から数え上げ、止まった瞬間に少し大きく出て戻る
		var k := clampf(_age / COUNT_SEC, 0.0, 1.0)
		_time.text = _time_text(roundi(_ticks * (1.0 - pow(1.0 - k, 3.0))))
		_time.scale = Vector2.ONE * (1.0 + 0.18 * (1.0 - clampf((_age - COUNT_SEC) / 0.22, 0.0, 1.0)) * float(k >= 1.0))
		if _diff != null:
			var kd := clampf((_age - COUNT_SEC) / 0.2, 0.0, 1.0)
			_diff.modulate.a = kd
			_diff.scale = Vector2.ONE * (1.0 + (0.4 if _diff_new else 0.0) * (1.0 - kd))
		if _badge != null:
			var kb := clampf((_age - BADGE_AT) / 0.3, 0.0, 1.0)
			_badge.size.y = 44.0 * (1.0 if kb >= 1.0 else ease(kb, -2.5) * 1.0)
			_badge.scale = Vector2.ONE * (1.0 + 0.3 * sin(kb * PI))
			_badge.pivot_offset = Vector2(100, 22)
		if _party != null:
			_party.age = _age - BADGE_AT
			_party.queue_redraw()
	if _toast_at >= 0.0:
		var kt := clampf((_age - _toast_at) / 0.2, 0.0, 1.0)
		_toast.scale = Vector2.ONE * (1.0 if calm else 0.8 + 0.2 * ease(kt, -2.5))


func can_retry() -> bool:
	return not _retry.disabled


# 「新しい記録」の札: 砂の色の丸い札に濃い字(色だけでなく字で伝える)。
class Badge extends Control:
	func _draw() -> void:
		if size.y < 2.0:
			return
		var r := Rect2(Vector2.ZERO, Vector2(size.x, 44))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Kit.C_SAND
		sb.set_corner_radius_all(22)
		sb.shadow_color = Color("8A6420")
		sb.shadow_offset = Vector2(0, 4)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var f := Kit.font(800)
		var w := f.get_string_size(S.NEW_RECORD, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(f, Vector2((size.x - w) / 2.0, 31), S.NEW_RECORD, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Kit.C_INK)


# 自己最高の祝い: 時間の周りから泡が 16 個はじけて昇り、輪が 2 つ広がる(1.4 秒で消える)。
class Party extends Control:
	var age := -1.0

	func _draw() -> void:
		if age < 0.0 or age > 1.4:
			return
		var c := Vector2(size.x / 2.0, 174)
		for k in 2:
			var a := clampf((age - k * 0.15) / 0.6, 0.0, 1.0)
			if a > 0.0 and a < 1.0:
				draw_arc(c, 80.0 + 260.0 * a, 0, TAU, 64, Color(Kit.C_SAND if k == 0 else Kit.C_AQUA, 0.7 * (1.0 - a)), 4.0, true)
		for i in 16:
			var dir := Vector2.from_angle(TAU * i / 16.0 + 0.3)
			var p := c + dir * Vector2(300, 120) * minf(age * 2.0, 1.0) + Vector2(0, -90.0 * age * age)
			var fade := clampf(1.4 - age, 0.0, 1.0)
			Kit.draw_bubble(self, p, 5.0 + (i % 4) * 3.0, fade)
