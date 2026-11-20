# 画面の共通部品(色・字体・ラベル・ボタン・置き場所)。画面設計書 §9 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
extends RefCounted

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"

const C_BG := Color("0E1116")
const C_BG_TOP := Color("18202B")
const C_WALL := Color("3A4658")
const C_WALL_EDGE := Color("55657C")
const C_SLICK := Color("9FB3C8")
const C_SPIKE := Color("FF4D4D")
const C_BRITTLE := Color("C9A66B")
const C_LEDGE := Color("E6E6E6")
const C_TAKO := Color("FF7A59")
const C_SUCKER := Color("FFD0C2")
const C_TEXT := Color("E6E6E6")
const C_DIM := Color("8B95A5")
const C_FAST := Color("7CE38B")
const C_SEL := Color("FF7A59")

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


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


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.anti_aliasing = true
	return s


# ボタン。node_name は自動の確認が押す時の目印。
static func button(node_name: String, text: String, size: int = 32) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	set_selected(b, false)
	b.add_theme_stylebox_override("pressed", box(Color(C_SEL, 0.3), C_SEL, 3))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.02), Color(C_DIM, 0.3), 2))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, C_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.5))
	return b


static func set_selected(b: Button, on: bool) -> void:
	var edge := C_SEL if on else Color(C_TEXT, 0.55)
	var fill := Color(C_SEL, 0.18) if on else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("normal", box(fill, edge, 3 if on else 2))
	b.add_theme_stylebox_override("hover", box(Color(C_SEL, 0.12), C_SEL, 3))


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


# タコ(丸・目 2 個・足の線 4 本。丸と線だけ)。sx・sy でつぶし、alpha で薄くする。
# look は目を寄せる向き(長さ 0〜1)、legs は足の生える向き(長さ 1。既定は下)、wiggle は足の揺れ(px)、blink で目を閉じる。
static func draw_tako(ci: CanvasItem, p: Vector2, sx: float, sy: float, color: Color, look := Vector2.ZERO,
		legs := Vector2(0, 1), wiggle := 0.0, blink := false) -> void:
	var r := 16.0
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(p + Vector2(cos(a) * r * sx, sin(a) * r * sy))
	var n := Vector2(-legs.y, legs.x)
	for i in 4:
		var o := i - 1.5
		var w := wiggle * (1.0 if i % 2 == 0 else -1.0)
		var base := p + (legs * (r - 3.0) + n * (o * 7.0)) * Vector2(sx, sy)
		ci.draw_line(base, base + legs * 9.0 + n * (o * 2.5 + w), color, 3.0, true)
	ci.draw_colored_polygon(pts, color)
	var eye := Color(0.06, 0.07, 0.09, color.a)
	for side: float in [-1.0, 1.0]:
		var e := p + Vector2(side * 5.5 * sx, -3.0 * sy) + look * 2.0
		if blink:
			ci.draw_line(e - Vector2(2.6, 0), e + Vector2(2.6, 0), eye, 1.6, true)
		else:
			ci.draw_circle(e, 2.6, eye)
			ci.draw_circle(e + Vector2(-0.8, -0.9), 0.9, Color(1, 1, 1, 0.9 * color.a))
