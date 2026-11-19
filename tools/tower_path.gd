# 積んだ塔を、腕だけで下からゴールまで登れるかを探し(§9.6 の検査と同じ探し方を塔全体で)、見つけた道を Climb で流して確かめる。
# 前提 11(つなぎ目の決まりで、どの区画からでも上の区画へ入れる)を確かめるための道具。入力の記録を JSON で出せる。
# 実行: python tools/gd.py run res://tools/tower_path.gd [tower=s01,s02r,s01r,s02,s01 | fixed | daily=<種>] [reach=288] [out=res://...json]
extends SceneTree

const B := preload("res://core/balance.gd")
const Store := preload("res://core/segment_store.gd")
const Check := preload("res://core/segment_check.gd")
const Grid := preload("res://core/grid.gd")
const Tower := preload("res://core/tower.gd")
const Climb := preload("res://core/climb.gd")
const Cast := preload("res://core/cast.gd")


func _initialize() -> void:
	var spec := "fixed"
	var reach := B.CHECK_REACH
	var out_path := ""
	var span := B.CHECK_DIR_SPAN
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("tower="):
			spec = a.substr(6)
		elif a.begins_with("reach="):
			reach = int(a.substr(6))
		elif a.begins_with("out="):
			out_path = a.substr(4)
		elif a.begins_with("span="):
			span = int(a.substr(5))
		elif a == "fixed" or a.begins_with("daily=") or a.begins_with("days="):
			spec = a
	var j := JSON.new()
	j.parse(FileAccess.get_file_as_string(Store.PATH))
	var segs: Array = []
	for s: Dictionary in j.data["segments"]:
		segs.append({"id": s["id"], "tier": int(s["tier"]), "rows": Array(s["rows"])})
	if spec.begins_with("days="):  # 通し日数の範囲の今日の塔を全部(例: days=322-687)。同じ並びは 1 回だけ
		var ab := spec.substr(5).split("-")
		var done := {}
		var bad := 0
		var ticks := []
		for day in range(int(ab[0]), int(ab[1]) + 1):
			var tw: RefCounted = Tower.daily(segs, preload("res://core/day_index.gd").daily_seed(day))
			if done.has(tw.name):
				continue
			var r := find(tw, reach, Check.dirs(span))
			var ok: bool = r["ok"] and replay(tw, timed(tw, r["path"])).is_over()
			done[tw.name] = ok
			if not ok:
				bad += 1
				print("登れない: 日 %d %s" % [day, tw.name])
		print("日 %s〜%s: 並び %d 種、登れない %d" % [ab[0], ab[1], done.size(), bad])
		quit(1 if bad > 0 else 0)
		return
	var tower: RefCounted = make_tower(spec, segs)
	print("塔: ", tower.name, "  届く距離 ", reach)
	var t0 := Time.get_ticks_usec()
	var r := find(tower, reach, Check.dirs(span))
	print("探索: %s 状態 %d 最上 y %d  %.1f 秒  タップ %d 回" % ["見つけた" if r["ok"] else "見つからない", r["states"],
		int(r["best_y"]), (Time.get_ticks_usec() - t0) / 1e6, r["path"].size()])
	if not r["ok"]:
		quit(1)
		return
	var moves := timed(tower, r["path"])
	var c := replay(tower, moves)
	print("Climb で再生: ゴール %s  tick %d  手数 %d  ミス %d  区切り %s" % [c.is_over(), c.clock, c.moves, c.misses, c.splits])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"tower": tower.name, "moves": moves, "ticks": c.clock, "count": c.moves}))
		f.close()
		print("書いた: ", out_path)
	quit(0 if c.is_over() else 1)


static func make_tower(spec: String, segs: Array) -> RefCounted:
	if spec == "fixed":
		return Tower.fixed(segs)
	if spec.begins_with("daily="):
		return Tower.daily(segs, int(spec.substr(6)))
	var list := []
	for part: String in spec.split(","):
		var flip := part.ends_with("r")
		var id := part.trim_suffix("r")
		list.append({"id": id, "rows": Tower._by_id(segs, id)["rows"], "flip": flip})
	return Tower.from_list(list)


# 塔の地図で、区画 1 の C からゴールの段の足場の上面より 16 px 上まで探す。
static func find(tower: RefCounted, reach: int, dir_list: Array) -> Dictionary:
	var grid: RefCounted = Grid.from_rows(tower.lines)
	return Check.search(grid, tower.seg_start(0), tower.goal_y() - B.CHECK_GOAL_ABOVE, reach, dir_list, 1000000)


# 道(タップの点の列)を、張り付くたびに次を押す入力の記録 [tick, wx, wy] にする。
# 探索はもろい壁を張り付ける壁として扱う(§9.6)ので、本番で崩れた壁が道に当たる時は、立っている所が安全なら戻るのを待つ。
# それでも探した時と違う所に着いたら(崩れて落ちた等)、今の位置から探し直す。
static func timed(tower: RefCounted, path: Array) -> Array:
	var c: RefCounted = Climb.new(tower)
	var grid0: RefCounted = Grid.from_rows(tower.lines)
	var dir_list := Check.dirs()
	var goal: float = tower.goal_y() - B.CHECK_GOAL_ABOVE
	var plan := path.duplicate()
	var moves := []
	var expect: Variant = null
	var replans := 0
	while not c.is_over() and c.sim_tick < 120 * 600:
		var guard := 0
		while (c.state != Climb.STICK and c.state != Climb.STAND or c.cast_lock > 0) and not c.is_over() and guard < 2000:
			c.step()
			guard += 1
		if c.is_over():
			break
		if plan.is_empty() or (expect is Vector2 and Vector2(c.x, c.y).distance_to(expect) > 0.5):
			replans += 1
			if replans > 40:
				break
			var r := Check.search(grid0, Vector2.ZERO, goal, B.CHECK_REACH, dir_list, 1000000, c.x, c.y)
			if not r["ok"]:
				break
			plan = r["path"]
		var tap: Vector2i = plan.pop_front()
		var want: Dictionary = Cast.cast(grid0, c.x, c.y, tap.x, tap.y, B.ARM_REACH)
		var wait := 0
		while wait < 500 and _safe_to_wait(c) and Cast.cast(c.grid, c.x, c.y, tap.x, tap.y, B.ARM_REACH)["anchor_y"] != want["anchor_y"]:
			c.step()
			wait += 1
		expect = Vector2(want["anchor_x"], want["anchor_y"]) if want["result"] == "ok" else Vector2(c.x, c.y)
		moves.append([c.sim_tick, tap.x, tap.y])
		c.queue_cast(tap.x, tap.y)
		c.step()
	return moves


# 体が数えているもろい壁の上にいなければ、待っても落ちない。
static func _safe_to_wait(c: RefCounted) -> bool:
	var col: int = c.tile_col
	var row: int = c.tile_row
	if c.state == Climb.STAND:
		col = floori(c.x / B.TILE)
		row = floori((c.y + B.STAND_PROBE) / B.TILE)
	return not c.brittle.has(row * c.grid.cols + col)


static func replay(tower: RefCounted, moves: Array) -> RefCounted:
	var c: RefCounted = Climb.new(tower)
	var i := 0
	while not c.is_over() and c.sim_tick < 120 * 600:
		while i < moves.size() and int(moves[i][0]) == c.sim_tick:
			c.queue_cast(int(moves[i][1]), int(moves[i][2]))
			i += 1
		c.step()
	return c
