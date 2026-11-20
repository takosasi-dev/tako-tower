# S3 結果(画面設計書 §4)。時間・最高との差・手数とミス・区画の表・やり直す・共有する文字の枠・コピー・タイトルへ。
# やり直すは 300 ms 後から押せる。コピーは clipboard_set を試し、選べる枠も常に出す(E-16)。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://core/time_text.gd")
const Kit := preload("res://ui/kit.gd")

var share := ""
var shown_at := 0
var _age := 0.0  # 画面に入ってからの時間(秒)
var _retry: Button
var _copied: Label
var _time: Label
var _diff: Label = null
var _diff_new := false


# rec は save_store.record() の戻り値。prev は前の最高の記録(無ければ null)。
func build(result: Dictionary, rec: Dictionary, share_text: String) -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	share = share_text
	shown_at = Time.get_ticks_msec()
	var ticks := int(result["ticks"])
	add_child(Kit.place(Kit.label(S.RESULT_TITLE, 40, Kit.C_DIM, 700), 0, 60, B.VIEW_W, 56))
	_time = Kit.label(S.RESULT_TIME % T.secs(ticks), 96, Kit.C_TEXT, 800)
	add_child(Kit.place(_time, 0, 116, B.VIEW_W, 130))
	_time.pivot_offset = _time.size / 2.0
	var prev: Variant = rec["prev"]
	if prev is Dictionary:
		var d := ticks - int(prev["best_ticks"])
		var text := S.DIFF_NEW % T.secs(-d) if rec["new_best"] else S.DIFF_BEHIND % T.secs(d)
		_diff = Kit.label(text, 28, Kit.C_FAST if rec["new_best"] else Kit.C_DIM, 700)
		add_child(Kit.place(_diff, 0, 248, B.VIEW_W, 40))
		_diff.pivot_offset = _diff.size / 2.0
		_diff_new = rec["new_best"]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 80)
	row.add_child(Kit.label(S.RESULT_MOVES % int(result["moves"]), 32, Kit.C_TEXT, 500))
	row.add_child(Kit.label(S.RESULT_MISSES % int(result["misses"]), 32, Kit.C_TEXT, 500))
	add_child(Kit.place(row, 0, 300, B.VIEW_W, 50))
	_table(result, prev)
	_retry = Kit.place(Kit.button("retry", S.BTN_RETRY, 36), 80, 712, 560, 120)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = true
	box.focus_mode = Control.FOCUS_CLICK
	box.add_theme_font_override("font", Kit.font(400))
	box.add_theme_font_size_override("font_size", 22)
	box.add_theme_color_override("font_readonly_color", Kit.C_TEXT)
	for st: String in ["normal", "read_only", "focus"]:  # 枠だと分かるように縁を付ける
		box.add_theme_stylebox_override(st, Kit.box(Color(1, 1, 1, 0.03), Color(Kit.C_DIM, 0.5), 1))
	add_child(Kit.place(box, 60, 860, 600, 124))
	var copy := Kit.place(Kit.button("copy", S.BTN_COPY, 30), 60, 1000, 280, 88)
	var title := Kit.place(Kit.button("title", S.BTN_TITLE, 30), 380, 1000, 280, 88)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 22, Kit.C_DIM)
	add_child(Kit.place(_copied, 0, 1100, B.VIEW_W, 36))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 22, Kit.C_SPIKE), 0, 1144, B.VIEW_W, 36))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())


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
	var cols := [S.TABLE_SEG, S.TABLE_NOW] + ([S.TABLE_BEST, S.TABLE_DIFF] if not best.is_empty() else [])
	# 列の中心。最高が無い時は 2 列を真ん中に寄せる
	var xs := [110.0, 270.0, 430.0, 590.0] if not best.is_empty() else [270.0, 450.0]
	var y := 376.0
	for c in cols.size():
		add_child(Kit.place(Kit.label(cols[c], 22, Kit.C_DIM, 500), xs[c] - 70, y, 140, 36))
	for i in now.size():
		y += 54
		# 一番遅れた区画は、タコの色の帯と字で目立たせる(速い色の緑は使わない。磨きで直した)
		if i == worst:
			var band := ColorRect.new()
			band.color = Color(Kit.C_TAKO, 0.14)
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.name = "worst"
			add_child(Kit.place(band, 40, y - 4, B.VIEW_W - 80, 48))
		var cells := [str(i + 1), T.secs(int(now[i]))]
		if not best.is_empty():
			cells += [T.secs(int(best[i])), T.diff(int(now[i]) - int(best[i]))]
		for c in cells.size():
			var color := Kit.C_TAKO if i == worst else Kit.C_TEXT
			if c == 3 and i != worst:
				color = Kit.C_FAST if int(now[i]) < int(best[i]) else Kit.C_DIM  # 差: 速い・遅い(画面設計書 §9)
			add_child(Kit.place(Kit.label(cells[c], 26, color, 700 if i == worst else 500), xs[c] - 70, y, 140, 40))


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


func _process(delta: float) -> void:
	_age += delta
	if _retry.disabled and _age >= B.RESULT_INPUT_DELAY_SEC:
		_retry.disabled = false
	# 入った瞬間、時間が少し大きく出て戻る。新しい記録の行は 0.25 秒遅れて同じように出る(磨きで足した物)
	_time.scale = Vector2.ONE * (1.0 + 0.25 * (1.0 - clampf(_age / 0.22, 0.0, 1.0)))
	if _diff != null:
		var k := clampf((_age - 0.25) / 0.2, 0.0, 1.0)
		_diff.modulate.a = k
		_diff.scale = Vector2.ONE * (1.0 + (0.4 if _diff_new else 0.0) * (1.0 - k))


func can_retry() -> bool:
	return not _retry.disabled
