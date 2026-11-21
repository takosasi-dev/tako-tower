# 画面の共通部品(色・字体・ラベル・ボタン・置き場所・Theme・飾り)。画面設計書 §9・§11 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
# 見た目(v0.3.0): 海の中のポップ。深い海の青緑の背景、珊瑚のタコと一番目のボタン、水色のフォーカスと選んだ値、泡の粒。
# Theme は make_theme() で組み、tools/make_theme.gd が ui/theme.tres に書く(project の gui/theme/custom)。色を変えたら回し直す。
extends RefCounted

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const DISPLAY := "res://assets/fonts/Fredoka-Subset.ttf"  # 題字と数字(SIL OFL。日本語は SANS へ落ちる)

# 海(背景)。下ほど深い
const C_BG := Color("082231")
const C_BG_TOP := Color("0F3A4E")
const C_FIELD_TOP := Color("0A2A3B")  # 塔の上の方の背景(トゲ・壁の縁との比を v0.2.0 と同じくらいに保つため、画面の後ろより暗い)
const C_PANEL := Color("124055")  # 二番目のボタン・枠
const C_PANEL_HI := Color("1A5470")  # その上にマウスが来た時
const C_EDGE := Color("4F8FA3")  # 二番目のボタンの縁
const C_LIP := Color("04141D")  # ボタンの下の厚み
const C_INK := Color("062030")  # 明るい面の上の字
const C_CORAL := Color("FF7A59")  # 一番目のボタン(タコと同じ珊瑚)
const C_CORAL_HI := Color("FF9677")
const C_CORAL_LIP := Color("B8452D")
const C_AQUA := Color("4FE0CF")  # フォーカスの輪・選んだ値
const C_AQUA_HI := Color("7CEDE0")
const C_AQUA_LIP := Color("1F8F86")
const C_PINK := Color("FF9EB8")  # 珊瑚の桃(飾り)
const C_SAND := Color("FFD27A")  # 新しい記録

# 遊びの場(画面設計書 §9 を海の色に寄せた。形と模様は元のまま)
const C_WALL := Color("2B5163")
const C_WALL_EDGE := Color("5B8C9E")
const C_SLICK := Color("A9CCD8")
const C_SPIKE := Color("FF4D4D")
const C_BRITTLE := Color("D2AE6F")
const C_LEDGE := Color("EAF6F4")
const C_TAKO := Color("FF7A59")
const C_SUCKER := Color("FFD0C2")
const C_TEXT := Color("EAF6F4")
const C_DIM := Color("94B8C4")
const C_FAST := Color("7CE38B")
const C_SEL := C_CORAL

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	return _variation(SANS, weight)


# 題字と数字の字体。日本語の字(「秒」など)は SANS の同じ太さへ落ちる。
static func display(weight: int = 600) -> Font:
	return _variation(DISPLAY, weight)


static func _variation(path: String, weight: int) -> Font:
	var k := "%s:%d" % [path, weight]
	if not _fonts.has(k):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		if path == DISPLAY:
			fv.fallbacks = [font(mini(weight + 100, 900))]
		_fonts[k] = fv
	return _fonts[k]


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# 数字のラベル(Fredoka)。outline を付けると、どんな背景の上でも読める縁取りになる。
static func number(text: String, size: int, color: Color = C_TEXT, outline: int = 0) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", display(600))
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", C_BG)
	return l


# ボタン。node_name は自動の確認が押す時の目印。kind は Theme の型の名前("" は二番目のボタン、"Primary"・"Chip"・"ChipOn")。
static func button(node_name: String, text: String, size: int = 32, kind: String = "") -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.theme_type_variation = kind
	b.focus_mode = Control.FOCUS_ALL
	if size != 32:
		b.add_theme_font_size_override("font_size", size)
	b.focus_entered.connect(func() -> void:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # マウスで押した時のフォーカスでは鳴らさない
			ui_sound("move"))
	b.pressed.connect(func() -> void:
		if not b.has_meta("quiet"):  # 音量の値は自分で張り付く音を鳴らす(1 回だけ)
			ui_sound("ok"))
	return b


# 音の autoload は名前で引く(tools の --script では Kit を読む時にまだ居ないため)。
static func ui_sound(kind: String) -> void:
	var sfx := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.ui(kind)


# 選んだ値: 水色の塗りと濃い字(選んでいない値は縁だけ)。塗りと縁の違いで、色を見なくても分かる。
static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = "ChipOn" if on else "Chip"


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


# --- Theme(tools/make_theme.gd が ui/theme.tres に書く) ---

static func _box(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 44, lip: int = 0, lip_color: Color = C_LIP) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.anti_aliasing = true
	if lip > 0:  # 下の厚み(ぷっくりしたボタン)。押すと薄くなり、字が下がる
		s.shadow_color = lip_color
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, lip)
	return s


static func _button_set(t: Theme, type: String, fill: Color, hi: Color, edge: Color, lip_color: Color, ink: Color, radius: int) -> void:
	t.set_stylebox("normal", type, _box(fill, edge, 2, radius, 6, lip_color))
	t.set_stylebox("hover", type, _box(hi, edge, 2, radius, 6, lip_color))
	var pressed := _box(hi, edge, 2, radius, 2, lip_color)
	pressed.content_margin_top += 8  # 押すと字が沈む
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, _box(Color(fill, 0.35), Color(edge, 0.35), 2, radius))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, type, ink)
	t.set_color("font_disabled_color", type, Color(ink, 0.45))


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = 28
	t.set_color("font_color", "Label", C_TEXT)
	# ボタン(二番目: 深い海の面と水色がかった縁)
	_button_set(t, "Button", C_PANEL, C_PANEL_HI, C_EDGE, C_LIP, C_TEXT, 44)
	t.set_font("font", "Button", font(700))
	t.set_font_size("font_size", "Button", 32)
	# フォーカスの輪: 水色 4 px を外側に 7 px(キーボードだけで遊ぶ人に見える)
	var focus := _box(Color.TRANSPARENT, C_AQUA, 4, 52)
	focus.draw_center = false
	focus.set_expand_margin_all(7)
	focus.expand_margin_bottom = 12  # 下の厚みも囲む
	t.set_stylebox("focus", "Button", focus)
	# 一番目のボタン(珊瑚)
	t.set_type_variation("Primary", "Button")
	_button_set(t, "Primary", C_CORAL, C_CORAL_HI, C_CORAL_HI, C_CORAL_LIP, C_INK, 44)
	t.set_font("font", "Primary", font(800))
	# 設定の値(選んでいない: 縁だけ / 選んだ: 水色の塗り)
	t.set_type_variation("Chip", "Button")
	_button_set(t, "Chip", Color(C_PANEL, 0.6), C_PANEL_HI, Color(C_EDGE, 0.8), C_LIP, C_TEXT, 30)
	t.set_type_variation("ChipOn", "Button")
	_button_set(t, "ChipOn", C_AQUA, C_AQUA_HI, C_AQUA_HI, C_AQUA_LIP, C_INK, 30)
	t.set_font("font", "ChipOn", font(800))
	# 文字の枠・入力欄
	for type: String in ["TextEdit", "LineEdit"]:
		for st: String in ["normal", "read_only", "focus"]:
			var s := _box(Color(C_BG, 0.7), C_AQUA if st == "focus" else Color(C_EDGE, 0.6), 2, 18)
			s.content_margin_left = 18
			s.content_margin_top = 10
			t.set_stylebox(st, type, s)
		t.set_color("font_color", type, C_TEXT)
		t.set_color("font_readonly_color", type, C_TEXT)
		t.set_color("font_uneditable_color", type, C_TEXT)
		t.set_color("selection_color", type, Color(C_AQUA, 0.35))
		t.set_color("font_selected_color", type, C_TEXT)
		t.set_color("caret_color", type, C_AQUA)
		t.set_color("background_color", type, Color.TRANSPARENT)
		t.set_font("font", type, font(400))
		t.set_font_size("font_size", type, 22)
	# スクロールバー(細い丸)
	for type: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, _box(Color(C_BG, 0.6), Color.TRANSPARENT, 0, 6))
		t.set_stylebox("scroll_focus", type, _box(Color(C_BG, 0.6), Color.TRANSPARENT, 0, 6))
		for st: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var g := _box(C_EDGE if st == "grabber" else C_AQUA, Color.TRANSPARENT, 0, 6)
			g.content_margin_left = 4
			g.content_margin_right = 4
			t.set_stylebox(st, type, g)
	# スライダー(今は使っていないが、既定の見た目に戻らないように)
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, _box(C_PANEL, Color.TRANSPARENT, 0, 6))
		t.set_stylebox("grabber_area", type, _box(C_AQUA, Color.TRANSPARENT, 0, 6))
		t.set_stylebox("grabber_area_highlight", type, _box(C_AQUA_HI, Color.TRANSPARENT, 0, 6))
	# 右クリックの品書き・ツールチップ・パネル
	var menu := _box(C_PANEL, C_EDGE, 2, 16)
	menu.set_content_margin_all(10)
	t.set_stylebox("panel", "PopupMenu", menu)
	t.set_stylebox("hover", "PopupMenu", _box(Color(C_AQUA, 0.25), Color.TRANSPARENT, 0, 10))
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_TEXT)
	t.set_color("font_disabled_color", "PopupMenu", Color(C_DIM, 0.6))
	t.set_color("font_accelerator_color", "PopupMenu", C_DIM)
	t.set_font("font", "PopupMenu", font(500))
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_constant("v_separation", "PopupMenu", 10)
	t.set_stylebox("panel", "TooltipPanel", menu)
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, C_EDGE, 2, 24))
	t.set_stylebox("panel", "Panel", _box(C_PANEL, C_EDGE, 2, 24))
	return t


# --- 飾り(_draw で描く。画像の素材は使わない) ---

# 泡: 細い輪と、左上の小さな光。
static func draw_bubble(ci: CanvasItem, p: Vector2, r: float, a: float) -> void:
	ci.draw_arc(p, r, 0, TAU, maxi(12, int(r * 2.0)), Color(C_TEXT, 0.5 * a), maxf(1.5, r * 0.12), true)
	ci.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), maxf(1.2, r * 0.2), Color(1, 1, 1, 0.55 * a))


# 海の背景: 上ほど明るい縦の濃淡と、斜めに差す光の帯。rect は塗る範囲(画面の余りまで)。still で光を止める。
static func draw_sea(ci: CanvasItem, rect: Rect2, t: float, still := false) -> void:
	var steps := 16
	for i in steps:
		var y0 := rect.position.y + rect.size.y * i / float(steps)
		ci.draw_rect(Rect2(rect.position.x, y0, rect.size.x, rect.size.y / steps + 1.0), C_BG_TOP.lerp(C_BG, i / float(steps - 1)))
	for k in 3:
		var sway := 0.0 if still else sin(t * 0.25 + k * 1.7) * 30.0
		var x := rect.position.x + rect.size.x * (0.1 + 0.3 * k) + sway
		var top := rect.position.y
		var w := 70.0 + 30.0 * k
		var h := rect.size.y * 0.7
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + w, top),
			Vector2(x + w + h * 0.35, top + h), Vector2(x + h * 0.25, top + h)]), Color(C_AQUA, 0.04))


# タコ(丸・目 2 個・足の線 4 本。丸と線だけ)。sx・sy でつぶし、alpha で薄くする。r で大きさ(既定 16)。
# look は目を寄せる向き(長さ 0〜1)、legs は足の生える向き(長さ 1。既定は下)、wiggle は足の揺れ(px)、blink で目を閉じる。
static func draw_tako(ci: CanvasItem, p: Vector2, sx: float, sy: float, color: Color, look := Vector2.ZERO,
		legs := Vector2(0, 1), wiggle := 0.0, blink := false, r := 16.0) -> void:
	var u := r / 16.0
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(p + Vector2(cos(a) * r * sx, sin(a) * r * sy))
	var n := Vector2(-legs.y, legs.x)
	for i in 4:
		var o := i - 1.5
		var w := wiggle * (1.0 if i % 2 == 0 else -1.0)
		var base := p + (legs * (r - 3.0 * u) + n * (o * 7.0 * u)) * Vector2(sx, sy)
		ci.draw_line(base, base + legs * 9.0 * u + n * (o * 2.5 + w) * u, color, 3.0 * u, true)
	ci.draw_colored_polygon(pts, color)
	var eye := Color(0.06, 0.07, 0.09, color.a)
	for side: float in [-1.0, 1.0]:
		var e := p + Vector2(side * 5.5 * sx, -3.0 * sy) * u + look * 2.0 * u
		if blink:
			ci.draw_line(e - Vector2(2.6, 0) * u, e + Vector2(2.6, 0) * u, eye, 1.6 * u, true)
		else:
			ci.draw_circle(e, 2.6 * u, eye)
			ci.draw_circle(e + Vector2(-0.8, -0.9) * u, 0.9 * u, Color(1, 1, 1, 0.9 * color.a))
