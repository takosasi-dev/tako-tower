# 区画のデータと検査のテスト(§9.6・AC-16・AC-17・FR-27・E-18)。12 個と左右反転が (a)(b)(c) を通ること、
# 決まりに反する区画を形の検査が落とすこと。
extends "res://tests/suite.gd"

const Check := preload("res://core/segment_check.gd")


func test_data_loads() -> bool:
	var d := Store.load_file()
	ok(d["ok"], "読める: %s" % d.get("error", ""))
	eq(d.get("segments", []).size(), 12, "12 個")
	return true


func test_ac16_ac17_all_segments_solvable() -> bool:
	var d := Store.load_file()
	for s: Dictionary in d.get("segments", []):
		for flip: bool in [false, true]:
			var rows: Array = Store.flip_rows(s["rows"]) if flip else s["rows"]
			var name: String = s["id"] + ("r" if flip else "")
			var errs := Store.shape_errors({"id": name, "tier": s["tier"], "rows": rows})
			ok(errs.is_empty(), "%s の形: %s" % [name, errs])
			var r := Check.check(rows)
			ok(r["ok"], "%s が解ける: %s" % [name, r["starts"].map(func(x: Dictionary) -> bool: return x["ok"])])
	return true


func test_tier_rules() -> bool:
	for s: Dictionary in Store.load_file().get("segments", []):
		var used := "".join(s["rows"])
		if s["tier"] == 1:
			ok(not used.contains("X") and not used.contains("^") and not used.contains("B"), "%s: tier1 に X ^ B が無い(FR-12)" % s["id"])
	return true


func test_shape_check_rejects() -> bool:
	var good := seg_rows()
	eq(Store.shape_errors({"id": "g", "tier": 1, "rows": good}), [], "空の区画は形が通る")
	var bad := {
		"行が足りない": good.slice(0, 31),
		"知らない文字": seg_rows({10: "##......Z.......##"}),
		"上のつなぎ目": seg_rows({1: "##......#.......##"}),
		"側壁が無い": seg_rows({25: "...............###"}),
		"C が 2 個": seg_rows({20: "##......C.......##"}),
		"C の位置": seg_rows({30: "##...C..........##"}),
		"入口の足場": seg_rows({31: "##....######....##"}),
	}
	for why: String in bad:
		ok(not Store.shape_errors({"id": "b", "tier": 1, "rows": bad[why]}).is_empty(), "落とす: " + why)
	ok(not Store.shape_errors({"id": "b", "tier": 1, "rows": seg_rows({10: "##....XX........##"})}).is_empty(), "tier1 に X")
	ok(not Store.shape_errors({"id": "b", "tier": 2, "rows": good}).is_empty(), "tier2 で X を使っていない")
	ok(Store.shape_errors({"id": "b", "tier": 4, "rows": seg_rows({10: "##....XX^^BB....##"})}).is_empty(), "tier4 は全部使える")
	return true


func test_e18_broken_data() -> bool:
	eq(Store.parse("not json")["ok"], false, "JSON でない")
	eq(Store.parse("{\"version\": 1, \"segments\": []}")["ok"], false, "区画が無い")
	return true


func test_unsolvable_segment_fails() -> bool:
	# 下の段から上へ届く物が何も無い区画(側壁も切った)は落ちる
	var rows := seg_rows()
	for r in range(3, 24):
		rows[r] = ".................."
	var r := Check.check(rows)
	eq(r["ok"], false, "解けない区画を落とす")
	return true
