# 時間の表示・日付と種・共有する文字・塔の組み立て・乱数のテスト(AC-15・AC-18〜AC-20・AC-22・AC-28)。
extends "res://tests/suite.gd"

const T := preload("res://core/time_text.gd")
const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Rng := preload("res://core/rng.gd")


func test_ac15_time_text() -> bool:
	eq(T.secs(5110), "42.58", "5,110 tick")
	eq(T.secs(119), "0.99", "119 tick")
	eq(T.secs(120), "1.00", "120 tick")
	eq(T.secs(0), "0.00", "0 tick")
	eq(T.diff(-50), "−0.41", "速い差")
	eq(T.diff(132), "+1.10", "遅い差")
	eq(T.diff(0), "0.00", "同じ")
	eq(T.lap_ticks([900, 1980, 3050, 4200, 5110]), [900, 1080, 1070, 1150, 910], "区画ごとの時間")
	return true


func test_ac20_day_index() -> bool:
	eq(Day.day_index(2026, 1, 1), 0, "2026-01-01")
	eq(Day.day_index(2026, 11, 12), 315, "2026-11-12")
	eq(Day.day_index(2027, 1, 1), 365, "2027-01-01")
	eq(Day.day_index(2025, 12, 31), 0, "2025-12-31 は 0")
	eq(Day.day_index(2028, 3, 1), 790, "うるう年をまたぐ")
	eq(Day.daily_seed(315), (316 * 2654435761) & 0xFFFFFFFF, "種の式")
	ok(Day.daily_seed(0) != 0, "種は 0 にならない")
	return true


func test_rng_matches_xorshift32() -> bool:
	var r := Rng.new(1)
	eq(r.next(), 270369, "1 回目")
	eq(r.next(), 67634689, "2 回目")
	eq(Rng.new(0).state, 1, "0 は 1 にする")
	return true


func test_ac22_share_text() -> bool:
	eq(Share.make("2026-11-12", "daily", true, 5110, 61, 1),
		"TakoTower 2026-11-12(今日の塔・1回目)\n42.58秒 / 61手 / ミス 1\nhttps://takosasi-dev.github.io/tako-tower/", "今日の塔の 1 回目")
	eq(Share.make("2026-11-12", "daily", false, 120, 3, 0).split("\n")[0], "TakoTower 2026-11-12(今日の塔)", "2 回目以降")
	eq(Share.make("2026-11-12", "fixed", true, 120, 3, 0).split("\n")[0], "TakoTower 2026-11-12(いつもの塔)", "いつもの塔")
	return true


func _segments() -> Array:
	var d := Store.load_file()
	ok(d["ok"], "区画のデータが読める: %s" % d.get("error", ""))
	return d.get("segments", [])


func test_ac19_fixed_tower_name() -> bool:
	var segs := _segments()
	if segs.is_empty():
		return true
	var t: RefCounted = Tower.fixed(segs)
	eq(t.name, "s01,s03,s06,s09,s10", "いつもの塔の名前")
	eq(t.row_count(), 168, "168 行")
	return true


func test_ac18_daily_tower() -> bool:
	var segs := _segments()
	if segs.is_empty():
		return true
	var tiers := {}
	for s: Dictionary in segs:
		tiers[s["id"]] = s["tier"]
	var names := {}
	for day in 400:
		var seed := Day.daily_seed(day)
		var a: RefCounted = Tower.daily(segs, seed)
		var b: RefCounted = Tower.daily(segs, seed)
		if a.name != b.name:
			errors.append("種が同じなのに名前が違う: %d" % day)
		var parts: Array = a.parts
		var got := parts.map(func(p: Dictionary) -> int: return tiers[p["id"]])
		if got != [1, 2, 3, 4, 4]:
			errors.append("tier の順が違う: %s" % [got])
		if parts[3]["id"] == parts[4]["id"]:
			errors.append("区画 4 と 5 が同じ: %s" % a.name)
		names[a.name] = true
	ok(names.size() > 100, "いろいろな並びが出る: %d" % names.size())
	return true


func test_daily_tower_known_value() -> bool:
	# 式を変えると、同じ日の塔が変わる(INV-3)。2026-11-12 の塔を固定で確かめる
	var segs := _segments()
	if segs.is_empty():
		return true
	var r := Rng.new(Day.daily_seed(315))
	var want := []
	var t1: Array = ["s01", "s02"]
	want.append(t1[r.next_int(2)] + ("r" if r.next_int(2) == 1 else ""))
	var t2: Array = ["s03", "s04", "s05"]
	want.append(t2[r.next_int(3)] + ("r" if r.next_int(2) == 1 else ""))
	var t3: Array = ["s06", "s07", "s08"]
	want.append(t3[r.next_int(3)] + ("r" if r.next_int(2) == 1 else ""))
	var t4: Array = ["s09", "s10", "s11", "s12"]
	var a: String = t4[r.next_int(4)]
	want.append(a + ("r" if r.next_int(2) == 1 else ""))
	t4.erase(a)
	want.append(t4[r.next_int(3)] + ("r" if r.next_int(2) == 1 else ""))
	eq(Tower.daily(segs, Day.daily_seed(315)).name, ",".join(want), "§9.7 の順に引く")
	return true


func test_ac28_core_has_no_forbidden_calls() -> bool:
	var bad := ["extends Node", "sin(", "cos(", "randf", "randi", "Time.", "OS.", "Input"]
	for f: String in DirAccess.get_files_at("res://core"):
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://core".path_join(f))
		for line: String in text.split("\n"):
			var code := line.split("#")[0]
			for w: String in bad:
				if code.contains(w):
					errors.append("%s に %s: %s" % [f, w, line.strip_edges()])
		ok(text.contains("extends RefCounted"), "%s は RefCounted" % f)
	return true
