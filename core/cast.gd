# 腕の判定(§9.4・INV-4)。本番の Climb・区画の検査・影の再生は、すべてこの cast() を呼ぶ。
# 体と同じ大きさの玉を 4 px ずつ進め、最初に重なったマスで決める。平方根と割り算だけを使う(sin・cos は使わない)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Grid := preload("res://core/grid.gd")

const OK := "ok"
const TOO_CLOSE := "too_close"
const SLICK := "slick"
const SPIKE := "spike"
const NONE := "none"
const NEAR := "near"


# { result, anchor_x, anchor_y, tile_col, tile_row }。anchor は ok の時の張り付き先、それ以外は最後に調べた位置。
static func cast(grid: RefCounted, from_x: float, from_y: float, wx: int, wy: int, reach: int) -> Dictionary:
	var dx := float(wx) - from_x
	var dy := float(wy) - from_y
	var len2 := dx * dx + dy * dy
	if len2 < float(B.CAST_MIN_MOVE * B.CAST_MIN_MOVE):
		return {"result": NEAR, "anchor_x": from_x, "anchor_y": from_y, "tile_col": -1, "tile_row": -1}
	var length := sqrt(len2)
	var ux := dx / length
	var uy := dy / length
	var step := float(B.CAST_STEP)
	var n := reach / B.CAST_STEP
	var dist: PackedByteArray = grid.dist
	var cols: int = grid.cols
	var rows: int = grid.rows
	var t := float(B.TILE)
	var r := float(B.BODY_RADIUS)
	var k := 1
	while k <= n:
		var cx := from_x + ux * (step * k)
		var cy := from_y + uy * (step * k)
		# 周りが空いている間は、重なりえない回を飛ばす(結果は 1 回ずつ調べた時と同じ。4 px の余裕を持たせる)
		var col := floori(cx / t)
		var row := floori(cy / t)
		if row >= 0 and row < rows and col >= 0 and col < cols:
			var free := float((dist[row * cols + col] - 1) * B.TILE)
			if free >= r:
				k += 1 + maxi(ceili((free - r) / step) - 1, 0)
				continue
		if not grid.hit(cx, cy):
			k += 1
			continue
		var kind: int = grid.hit_kind
		var hcol: int = grid.hit_col
		var hrow: int = grid.hit_row
		if kind == Grid.WALL or kind == Grid.BRITTLE:
			# 進めた回数で決める(距離の小数の誤差で境目が揺れないように)
			var back := k - 1
			var result := TOO_CLOSE if back * B.CAST_STEP < B.CAST_MIN_MOVE else OK
			return {"result": result, "anchor_x": from_x + ux * (step * back), "anchor_y": from_y + uy * (step * back),
				"tile_col": hcol, "tile_row": hrow}
		return {"result": SLICK if kind == Grid.SLICK else SPIKE, "anchor_x": cx, "anchor_y": cy,
			"tile_col": hcol, "tile_row": hrow}
	return {"result": NONE, "anchor_x": from_x + ux * (step * n), "anchor_y": from_y + uy * (step * n),
		"tile_col": -1, "tile_row": -1}
