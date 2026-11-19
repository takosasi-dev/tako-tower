# 塔のマスの表と、円と四角の重なり(§9.1・§9.4)。左右の外はツルツル、一番下より下は地面(張り付ける壁)、上の外は空き。
# 玉と重なったマスのうち中心に一番近い物を返す(同じなら行が小さい方、次に列が小さい方)。結果は hit_* に置く。
extends RefCounted

const B := preload("res://core/balance.gd")

const EMPTY := 0
const WALL := 1
const SLICK := 2
const SPIKE := 3
const BRITTLE := 4

const CHAR_KIND := {".": EMPTY, "C": EMPTY, "#": WALL, "X": SLICK, "^": SPIKE, "B": BRITTLE}

var cols: int = B.COLS
var rows: int = 0
var cells := PackedByteArray()
# 各マスから、作った時に空きでなかったマス(左右の外・下の外を含む)までのチェビシェフ距離(マス)。
# もろい壁は崩れても数え続ける(距離は小さめに出るだけで、結果は変わらない)。腕の判定を速くするためだけに使う。
var dist := PackedByteArray()

# 直前の hit() の結果
var hit_kind: int = EMPTY
var hit_col: int = 0
var hit_row: int = 0


# 文字の行(上から)から作る。C は空き。
static func from_rows(lines: Array) -> RefCounted:
	var g: RefCounted = load("res://core/grid.gd").new()
	g.rows = lines.size()
	g.cols = (lines[0] as String).length() if not lines.is_empty() else B.COLS
	g.cells.resize(g.rows * g.cols)
	for r in g.rows:
		var line: String = lines[r]
		for c in g.cols:
			g.cells[r * g.cols + c] = CHAR_KIND.get(line[c], EMPTY)
	g._build_dist()
	return g


# 2 回なめるチェビシェフ距離の変換。
func _build_dist() -> void:
	dist.resize(rows * cols)
	for r in rows:
		for c in cols:
			var d := 0 if cells[r * cols + c] != EMPTY else mini(mini(c + 1, cols - c), mini(rows - r, 255))
			dist[r * cols + c] = d
	for r in rows:
		for c in cols:
			var d: int = dist[r * cols + c]
			if r > 0:
				d = mini(d, dist[(r - 1) * cols + c] + 1)
				if c > 0:
					d = mini(d, dist[(r - 1) * cols + c - 1] + 1)
				if c < cols - 1:
					d = mini(d, dist[(r - 1) * cols + c + 1] + 1)
			if c > 0:
				d = mini(d, dist[r * cols + c - 1] + 1)
			dist[r * cols + c] = d
	for r in range(rows - 1, -1, -1):
		for c in range(cols - 1, -1, -1):
			var d: int = dist[r * cols + c]
			if r < rows - 1:
				d = mini(d, dist[(r + 1) * cols + c] + 1)
				if c > 0:
					d = mini(d, dist[(r + 1) * cols + c - 1] + 1)
				if c < cols - 1:
					d = mini(d, dist[(r + 1) * cols + c + 1] + 1)
			if c < cols - 1:
				d = mini(d, dist[r * cols + c + 1] + 1)
			dist[r * cols + c] = d


# 点 (x, y) から空きでないマスまでの距離の下限(px)。地図の上の外では 0。
func free_dist(x: float, y: float) -> float:
	var col := floori(x / B.TILE)
	var row := floori(y / B.TILE)
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return 0.0
	return float((dist[row * cols + col] - 1) * B.TILE)


func kind(col: int, row: int) -> int:
	if col < 0 or col >= cols:
		return SLICK
	if row >= rows:
		return WALL
	if row < 0:
		return EMPTY
	return cells[row * cols + col]


func set_kind(col: int, row: int, k: int) -> void:
	if col >= 0 and col < cols and row >= 0 and row < rows:
		cells[row * cols + col] = k


# 点 (x, y) があるマスの種類。
func kind_at(x: float, y: float) -> int:
	return kind(floori(x / B.TILE), floori(y / B.TILE))


# 円 (cx, cy, 半径 BODY_RADIUS) と重なる、空きでないマスのうち一番近い物。無ければ false。
# 重なりは「マスの四角の上で一番近い点までの距離 < 半径」(厳密な比べ。丁度 16 は重ならない)。
func hit(cx: float, cy: float) -> bool:
	var r := float(B.BODY_RADIUS)
	if free_dist(cx, cy) >= r:
		return false
	var t := float(B.TILE)
	var c0 := floori((cx - r) / t)
	var c1 := floori((cx + r) / t)
	var r0 := floori((cy - r) / t)
	var r1 := floori((cy + r) / t)
	var best := r * r
	var found := false
	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			var k := kind(col, row)
			if k == EMPTY:
				continue
			var x0 := col * t
			var y0 := row * t
			var nx := clampf(cx, x0, x0 + t)
			var ny := clampf(cy, y0, y0 + t)
			var d := (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny)
			if d < best:
				best = d
				found = true
				hit_kind = k
				hit_col = col
				hit_row = row
	return found


# 円が kind のマス (col, row) と重なるか。
func overlaps_tile(cx: float, cy: float, col: int, row: int) -> bool:
	var r := float(B.BODY_RADIUS)
	var t := float(B.TILE)
	var nx := clampf(cx, col * t, col * t + t)
	var ny := clampf(cy, row * t, row * t + t)
	return (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny) < r * r
