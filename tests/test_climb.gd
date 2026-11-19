# Climb の決まり(§9.3・§9.5)のテスト。AC-4・AC-6〜AC-14 と、連続の数・空振りの扱い。
extends "res://tests/suite.gd"

# 区画 1 の行は塔の 136〜167 行。C は (340, 6664)。入口の足場の上面は 6680。
const SEG1_TOP := 136
const START_X := 340.0
const START_Y := 6664.0


func _climb(edits: Dictionary) -> RefCounted:
	return Climb.new(tower_of(seg_rows(edits)))


func test_start_state() -> bool:
	var c := _climb({})
	eq(c.state, Climb.STAND, "始まりは STAND")
	eq(Vector2(c.x, c.y), Vector2(START_X, START_Y), "区画 1 の C に立つ")
	run(c, 10)
	eq(c.state, Climb.STAND, "足場の上で立ったまま")
	return true


func test_ac4_slick_locks_casts() -> bool:
	var c := _climb({25: "##......XX......##"})
	c.queue_cast(340, 6300)
	var ev := run(c, 1)
	eq(types(ev), ["cast_miss"], "X は空振り")
	eq(ev[0]["result"], "slick", "空振りの理由")
	eq(c.moves, 1, "空振りも手数に数える")
	for i in 35:
		c.queue_cast(100, 6664)  # 左の側壁(届けば ok)
		run(c, 1)
	eq(c.moves, 1, "36 tick の間のタップは捨てる")
	eq(c.state, Climb.STAND, "体は動かない")
	c.queue_cast(100, 6664)
	ev = run(c, 1)
	eq(types(ev), ["cast_ok"], "36 tick 後は出せる")
	return true


func test_ac6_fly_200px_in_20_ticks() -> bool:
	var c := _climb({24: "##......####....##"})  # 下面は y 6440
	c.state = Climb.STICK
	c.tile_col = 0
	c.tile_row = 166
	c.y = 6656.0
	c.queue_cast(340, 6300)
	var ev := run(c, 19)
	eq(types(ev), ["cast_ok"], "19 tick ではまだ着かない")
	eq(c.state, Climb.FLY, "飛んでいる")
	ev = run(c, 1)
	eq(types(ev), ["stick"], "20 tick 目に張り付く")
	eq(c.state, Climb.STICK, "STICK")
	eq(c.y, 6456.0, "張り付き先は 200 px 上")
	return true


func test_ac7_retarget_in_flight() -> bool:
	var c := _climb({24: "##......####....##"})
	c.queue_cast(340, 6300)
	run(c, 5)
	eq(c.state, Climb.FLY, "飛んでいる")
	c.queue_cast(int(c.x) - 400, int(c.y))  # 左の側壁へ
	var ev := run(c, 1)
	eq(types(ev), ["cast_ok"], "飛んでいる途中でも出せる")
	ok(c.dest_x < 100.0, "行き先が左の側壁に変わる: %s" % c.dest_x)
	settle(c)
	eq(c.state, Climb.STICK, "新しい張り付き先に張り付く")
	ok(c.x < 100.0, "左の側壁にいる")
	return true


func test_ac8_ac9_brittle_and_land() -> bool:
	var c := _climb({25: "##......BB......##"})
	c.queue_cast(340, 6300)
	var ev := settle(c)
	ok(types(ev).has("stick"), "もろい壁に張り付く")
	ok(types(ev).has("crumble_start"), "張り付いた tick に数え始める")
	var col := 8
	var row := SEG1_TOP + 25
	ev = run(c, B.CRUMBLE_TICKS - 1)
	eq(c.grid.kind(col, row), Grid.BRITTLE, "83 tick ではまだある")
	ev = run(c, 1)
	ok(types(ev).has("crumble"), "84 tick 後に崩れる")
	eq(c.grid.kind(col, row), Grid.EMPTY, "マスが空き")
	eq(c.state, Climb.FALL, "体は落ちる")
	ev = settle(c)
	ok(types(ev).has("land"), "下の足場に着地")
	eq(c.state, Climb.STAND, "STAND")
	eq(c.y, 6680.0 - 16.0, "中心が上面の 16 px 上")
	return true


func test_brittle_returns_after_360() -> bool:
	var c := _climb({25: "##......BB......##"})
	c.queue_cast(340, 6300)
	settle(c)
	var t0: int = c.sim_tick
	var crumbled := -1
	var back := -1
	for i in 600:
		run(c, 1)
		if crumbled < 0 and c.grid.kind(8, SEG1_TOP + 25) == Grid.EMPTY:
			crumbled = c.sim_tick
		if crumbled >= 0 and back < 0 and c.grid.kind(8, SEG1_TOP + 25) == Grid.BRITTLE:
			back = c.sim_tick
	eq(crumbled - t0, B.CRUMBLE_TICKS, "張り付いてから 84 tick で崩れる")
	eq(back - crumbled, B.CRUMBLE_BACK_TICKS, "崩れてから 360 tick で戻る")
	return true


func test_ac10_spike_miss_and_respawn() -> bool:
	var c := _climb({30: "##......C...^^..##"})
	c.clock_running = true
	c.state = Climb.FALL
	c.x = 520.0
	c.y = 6500.0
	var clock0: int = c.clock
	var ev := _until_miss(c)
	ok(types(ev).has("miss"), "トゲに重なるとミス")
	eq(c.misses, 1, "ミス数 +1")
	eq(c.state, Climb.RESPAWN, "RESPAWN")
	var t0: int = c.sim_tick
	while c.state == Climb.RESPAWN:
		run(c, 1)
	eq(c.sim_tick - t0, B.RESPAWN_TICKS, "48 tick で戻る")
	eq(c.state, Climb.STAND, "C に立つ")
	eq(Vector2(c.x, c.y), Vector2(START_X, START_Y), "中間地点の C")
	eq(c.clock - clock0, c.sim_tick, "その間も時計が進む")
	return true


func test_ac11_fall_below_checkpoint() -> bool:
	var c := _climb({})
	var t: RefCounted = c.tower
	c.checkpoint = 1
	c.state = Climb.FALL
	c.x = 140.0
	c.y = t.seg_bottom_y(1) - 100.0
	var ev := settle(c, 300)
	ok(types(ev).has("miss"), "最後に越えた区画の下端より 40 px 下でミス")
	eq(ev[ev.size() - 1]["reason"], "fall", "理由は fall")
	eq(Vector2(c.x, c.y), t.seg_start(1), "区画 2 の C へ戻る")
	# 区画 1 では地面に立つ
	var c2 := _climb({})
	c2.state = Climb.FALL
	c2.x = 140.0
	c2.y = 6500.0
	ev = settle(c2, 300)
	ok(not types(ev).has("miss"), "区画 1 ではミスにならない")
	eq(c2.state, Climb.STAND, "地面に立つ")
	eq(c2.y, 168 * 40.0 - 16.0, "地面の上面の 16 px 上")
	return true


func test_ac12_clock_starts_on_first_ok() -> bool:
	var c := _climb({25: "##......XX......##"})
	c.queue_cast(340, 6300)
	run(c, 60)
	eq(c.clock, 0, "空振りだけでは進まない")
	eq(c.clock_running, false, "時計は止まっている")
	c.queue_cast(100, 6664)
	run(c, 1)
	eq(c.clock_running, true, "最初の cast_ok で動く")
	eq(c.clock, 1, "その tick から数える")
	return true


func test_e6_restored_brittle_in_flight() -> bool:
	# 飛んでいる途中で、道の上にもろい壁が戻ると、1 tick 前の位置で張り付く
	var c := _climb({24: "##......####....##", 27: "##......B.......##"})
	var row := SEG1_TOP + 27  # 道の上(体より上、天井より下)
	c.grid.set_kind(8, row, Grid.EMPTY)  # 崩れて空いている
	c.queue_cast(340, 6300)
	run(c, 3)
	eq(c.state, Climb.FLY, "飛んでいる")
	c.grid.set_kind(8, row, Grid.BRITTLE)  # 戻る
	c.restores += 1
	var ev := settle(c, 100)
	ok(types(ev).has("stick"), "戻ったもろい壁に張り付く")
	eq(c.tile_row, row, "張り付いたのは戻ったマス")
	ok(c.y > (row + 1) * 40.0, "マスの下にいる")
	return true


func test_near_tap_ignored() -> bool:
	var c := _climb({})
	c.queue_cast(343, 6660)
	var ev := run(c, 1)
	eq(ev, [], "8 px 未満のタップは何も起きない")
	eq(c.moves, 0, "手数に数えない")
	eq(c.input_log, [], "記録にも残さない")
	return true


func test_respawn_drops_taps() -> bool:
	var c := _climb({30: "##......C...^^..##"})
	c.state = Climb.FALL
	c.x = 520.0
	c.y = 6500.0
	_until_miss(c)
	eq(c.state, Climb.RESPAWN, "RESPAWN")
	c.queue_cast(100, 6664)
	run(c, 1)
	eq(c.moves, 0, "RESPAWN の間のタップは捨てる")
	return true


func test_stick_chain() -> bool:
	var c := _climb({26: "##....######....##"})  # 天井の下面は y 6520
	c.queue_cast(340, 6300)
	var ev := settle(c)
	eq(ev[ev.size() - 1]["chain"], 1, "1 回目は 1")
	run(c, 1)
	c.queue_cast(0, int(c.y))  # 左の側壁へ水平に
	ev = settle(c)
	ok(types(ev).has("stick"), "もう 1 回張り付く")
	eq(ev[ev.size() - 1]["chain"], 2, "60 tick 以内なら連続 +1")
	run(c, 100)
	c.queue_cast(340, 6680)  # 入口の足場の上面へ
	ev = settle(c)
	var sticks := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "stick")
	ok(not sticks.is_empty() and sticks[0]["chain"] == 1, "間が空けば 1 に戻る: %s" % [sticks])
	return true


func test_ac13_ac14_full_tower_path() -> bool:
	var c := _replay_found()
	if c == null:
		return true
	eq(c.is_over(), true, "ゴールまで登れる")
	eq(c.splits.size(), 5, "区切りは 5 個")
	for i in range(1, c.splits.size()):
		ok(int(c.splits[i]) > int(c.splits[i - 1]), "区切りが増えていく")
	eq(c.splits[4], c.clock, "最後の区切りはゴールの時計")
	ok(c.y < c.tower.goal_y(), "体の中心がゴールの段の足場の上面より上")
	return true


func test_checkpoint_events_once() -> bool:
	var tw := _test_tower()
	var path := _path_for(tw)
	var c: RefCounted = Climb.new(tw)
	var cps := []
	var goals := 0
	var tp: GDScript = load("res://tools/tower_path.gd")
	var moves: Array = tp.timed(tw, path)
	var i := 0
	while not c.is_over() and c.sim_tick < 120 * 600:
		while i < moves.size() and int(moves[i][0]) == c.sim_tick:
			c.queue_cast(int(moves[i][1]), int(moves[i][2]))
			i += 1
		c.step()
		for e: Dictionary in c.events():
			if e["type"] == "checkpoint":
				cps.append(e["segment"])
			elif e["type"] == "goal":
				goals += 1
	eq(cps, [2, 3, 4, 5], "区画 2〜5 に 1 回ずつ")
	eq(goals, 1, "ゴールは 1 回")
	c.step()
	eq(c.events(), [], "終わった後は何も起きない")
	return true


func test_ac2_determinism_100() -> bool:
	var tw := _test_tower()
	var tp: GDScript = load("res://tools/tower_path.gd")
	var moves: Array = tp.timed(tw, _path_for(tw))
	var first: Dictionary = replay(tw, moves).result()
	var same := 0
	for k in 100:
		var r: Dictionary = replay(tw, moves).result()
		if r["ticks"] == first["ticks"] and r["moves"] == first["moves"] and r["misses"] == first["misses"]:
			same += 1
	eq(same, 100, "100 回とも同じ")
	return true


func test_ac23_json_roundtrip_goal_tick() -> bool:
	var tw := _test_tower()
	var tp: GDScript = load("res://tools/tower_path.gd")
	var moves: Array = tp.timed(tw, _path_for(tw))
	var a: RefCounted = replay(tw, moves)
	var back: Array = JSON.parse_string(JSON.stringify(a.result()["log"]))
	var b: RefCounted = replay(tw, back)
	eq(b.is_over(), true, "読み戻した記録でもゴールする")
	eq(b.clock, a.clock, "ゴールの tick が同じ")
	return true


func test_towers_climbable_across_seams() -> bool:
	# 前提 11: いつもの塔と今日の塔いくつかを、腕だけで下からゴールまで登れる(探して、Climb で流してゴールする)
	var d := Store.load_file()
	if not d["ok"]:
		errors.append("区画のデータが読めない")
		return true
	var tp: GDScript = load("res://tools/tower_path.gd")
	var towers: Array = [Tower.fixed(d["segments"])]
	for day: int in [0, 315, 365, 1000]:
		towers.append(Tower.daily(d["segments"], preload("res://core/day_index.gd").daily_seed(day)))
	for tw: RefCounted in towers:
		var r: Dictionary = tp.find(tw, B.CHECK_REACH, preload("res://core/segment_check.gd").dirs())
		ok(r["ok"], "%s を登る道がある" % tw.name)
		if r["ok"]:
			var c: RefCounted = replay(tw, tp.timed(tw, r["path"]))
			ok(c.is_over(), "%s を Climb で登れる" % tw.name)
	return true


static func _until_miss(c: RefCounted) -> Array:
	var ev := []
	for i in 300:
		c.step()
		ev.append_array(c.events())
		if c.misses > 0:
			break
	return ev


# 区画のデータの tier1 を交互に積んだ塔。
func _test_tower() -> RefCounted:
	var d := Store.load_file()
	var segs: Array = d["segments"] if d["ok"] else _raw_segments()
	var s01: Array = Tower._by_id(segs, "s01")["rows"]
	var s02: Array = Tower._by_id(segs, "s02")["rows"]
	return Tower.from_list([{"id": "s01", "rows": s01, "flip": false}, {"id": "s02", "rows": s02, "flip": true},
		{"id": "s01", "rows": s01, "flip": true}, {"id": "s02", "rows": s02, "flip": false}, {"id": "s01", "rows": s01, "flip": false}])


static func _raw_segments() -> Array:
	var j := JSON.new()
	j.parse(FileAccess.get_file_as_string(Store.PATH))
	var out := []
	for s: Dictionary in j.data["segments"]:
		out.append({"id": s["id"], "tier": int(s["tier"]), "rows": Array(s["rows"])})
	return out


func _path_for(tw: RefCounted) -> Array:
	var tp: GDScript = load("res://tools/tower_path.gd")
	var r: Dictionary = tp.find(tw, B.CHECK_REACH, preload("res://core/segment_check.gd").dirs())
	ok(r["ok"], "塔を腕だけで登る道が見つかる")
	return r["path"]


func _replay_found() -> RefCounted:
	var tw := _test_tower()
	var tp: GDScript = load("res://tools/tower_path.gd")
	return replay(tw, tp.timed(tw, _path_for(tw)))
