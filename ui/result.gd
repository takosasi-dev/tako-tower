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


# rec は save_store.record() の戻り値。prev は前の最高の記録(無ければ null)。
func build(result: Dictionary, rec: Dictionary, share_text: String) -> void:
	size = Vector2(B.VIEW_W, B.VIEW_H)
	share = share_text
	shown_at = Time.get_ticks_msec()
	var ticks := int(result["ticks"])
	add_child(Kit.place(Kit.label(S.RESULT_TITLE, 40, Kit.C_DIM, 700), 0, 70, B.VIEW_W, 56))
	add_child(Kit.place(Kit.label(S.RESULT_TIME % T.secs(ticks), 96, Kit.C_TEXT, 800), 0, 130, B.VIEW_W, 130))
	var prev: Variant = rec["prev"]
	if prev is Dictionary:
		var d := ticks - int(prev["best_ticks"])
		var text := S.DIFF_NEW % T.secs(-d) if rec["new_best"] else S.DIFF_BEHIND % T.secs(d)
		add_child(Kit.place(Kit.label(text, 28, Kit.C_FAST if rec["new_best"] else Kit.C_DIM, 700), 0, 264, B.VIEW_W, 40))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 80)
	row.add_child(Kit.label(S.RESULT_MOVES % int(result["moves"]), 32, Kit.C_TEXT, 500))
	row.add_child(Kit.label(S.RESULT_MISSES % int(result["misses"]), 32, Kit.C_TEXT, 500))
	add_child(Kit.place(row, 0, 320, B.VIEW_W, 50))
	_table(result, prev)
	_retry = Kit.place(Kit.button("retry", S.BTN_RETRY, 36), 80, 720, 560, 120)
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
	add_child(Kit.place(box, 60, 870, 600, 130))
	var copy := Kit.place(Kit.button("copy", S.BTN_COPY, 30), 60, 1016, 280, 88)
	var title := Kit.place(Kit.button("title", S.BTN_TITLE, 30), 380, 1016, 280, 88)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 22, Kit.C_DIM)
	add_child(Kit.place(_copied, 0, 1112, B.VIEW_W, 36))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 22, Kit.C_SPIKE), 0, 1160, B.VIEW_W, 36))
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
		var most: int = -1000000000
		for i in now.size():
			if int(now[i]) - int(best[i]) > most:
				most = int(now[i]) - int(best[i])
				worst = i
	var cols := [S.TABLE_SEG, S.TABLE_NOW] + ([S.TABLE_BEST, S.TABLE_DIFF] if not best.is_empty() else [])
	var xs := [90.0, 230.0, 390.0, 550.0]
	var y := 400.0
	for c in cols.size():
		add_child(Kit.place(Kit.label(cols[c], 22, Kit.C_DIM, 500), xs[c] - 60, y, 140, 36))
	for i in now.size():
		y += 52
		var color := Kit.C_FAST if i == worst else Kit.C_TEXT
		var cells := [str(i + 1), T.secs(int(now[i]))]
		if not best.is_empty():
			cells += [T.secs(int(best[i])), T.diff(int(now[i]) - int(best[i]))]
		for c in cells.size():
			add_child(Kit.place(Kit.label(cells[c], 26, color, 500 if i != worst else 700), xs[c] - 60, y, 140, 40))


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


func _process(delta: float) -> void:
	_age += delta
	if _retry.disabled and _age >= B.RESULT_INPUT_DELAY_SEC:
		_retry.disabled = false


func can_retry() -> bool:
	return not _retry.disabled
