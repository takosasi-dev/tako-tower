# 保存のテスト(§9.10・AC-21・AC-23・E-13〜E-15・E-17・E-20)。user:// の下の使い捨てのファイルで行う。
extends "res://tests/suite.gd"

const Save := preload("res://save/save_store.gd")
const P := "user://test_save.json"


func _write(text: String) -> void:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _fresh() -> RefCounted:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(P)
	return Save.new(P)


func _result(ticks: int, log: Array = [[0, 340, 6300]]) -> Dictionary:
	return {"ticks": ticks, "moves": 10, "misses": 1, "splits": [10, 20, 30, 40, ticks], "log": log}


func test_ac21_defaults_on_bad_save() -> bool:
	var s := _fresh()
	eq(s.load_failed, false, "保存が無いのは失敗ではない")
	eq(s.settings(), Save.default_settings(), "空なら既定値")
	for text: String in ["", "{not json", "{\"version\": 2, \"fixed\": null}"]:
		_write(text)
		var t: RefCounted = Save.new(P)
		eq(t.settings()["volume"], 75, "既定の音量: " + text)
		eq(t.data["fixed"], null, "記録なし: " + text)
		eq(t.settings()["ghost"], true, "影 入: " + text)
	_write("{not json")
	eq(Save.new(P).load_failed, true, "壊れた JSON は読めなかった印")
	return true


func test_ac21_broken_ghost_keeps_record() -> bool:
	var s := _fresh()
	s.record("fixed", 0, "s01,s03,s06,s09,s10", _result(900))
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(P))
	d["fixed"]["ghost"] = [[1, 2], "x"]
	_write(JSON.stringify(d))
	var t: RefCounted = Save.new(P)
	eq(t.load_failed, false, "読める")
	eq(t.best("fixed")["best_ticks"], 900, "記録は残る")
	eq(t.ghost("fixed", 0, "s01,s03,s06,s09,s10"), null, "影は出さない")
	return true


func test_record_fixed_best() -> bool:
	var s := _fresh()
	var r: Dictionary = s.record("fixed", 0, "a", _result(900))
	eq(r["new_best"], true, "初めての記録")
	r = s.record("fixed", 0, "a", _result(950))
	eq(r["new_best"], false, "遅い回は更新しない")
	eq(r["prev"]["best_ticks"], 900, "前の最高")
	r = s.record("fixed", 0, "a", _result(800))
	eq(r["new_best"], true, "速い回で更新")
	var t: RefCounted = Save.new(P)
	eq(t.best("fixed")["best_ticks"], 800, "読み戻しても同じ")
	eq(typeof(t.best("fixed")["best_ticks"]), TYPE_INT, "整数に直して読む")
	eq(t.ghost("fixed", 0, "a"), [[0, 340, 6300]], "影の記録")
	eq(t.ghost("fixed", 0, "b"), null, "塔の名前が違えば影を出さない(E-15)")
	return true


func test_record_daily_first_and_best() -> bool:
	var s := _fresh()
	var r: Dictionary = s.record("daily", 315, "x", _result(1000))
	eq(r["first_today"], true, "今日の 1 回目")
	r = s.record("daily", 315, "x", _result(900))
	eq(r["first_today"], false, "2 回目")
	eq(r["new_best"], true, "今日の最高を更新")
	var d: Dictionary = s.best("daily", 315)
	eq(d["first_ticks"], 1000, "1 回目の時間は残る")
	eq(d["best_ticks"], 900, "今日の最高")
	eq(s.best("daily", 316), null, "日付が違えば無し")
	r = s.record("daily", 316, "y", _result(2000))
	eq(r["first_today"], true, "次の日は作り直す")
	r = s.record("daily", 315, "x", _result(100))
	eq(s.best("daily", 316)["best_ticks"], 2000, "古い日の回は新しい日を置き換えない(E-17)")
	return true


func test_e20_long_log_no_ghost() -> bool:
	var s := _fresh()
	var long := []
	for i in B.GHOST_MAX_MOVES + 1:
		long.append([i, 1, 2])
	s.record("fixed", 0, "a", _result(900, long))
	var t: RefCounted = Save.new(P)
	eq(t.best("fixed")["best_ticks"], 900, "時間は保存する")
	eq(t.ghost("fixed", 0, "a"), null, "影は保存しない")
	return true


func test_settings_saved() -> bool:
	var s := _fresh()
	s.set_setting("volume", 25)
	s.set_setting("shake", false)
	var t: RefCounted = Save.new(P)
	eq(t.settings()["volume"], 25, "音量")
	eq(t.settings()["shake"], false, "揺れ")
	_write("{\"version\": 1, \"settings\": {\"volume\": 33}}")
	eq(Save.new(P).settings()["volume"], 75, "5 段に無い音量は既定値")
	return true


func test_ac23_ghost_roundtrip_replay() -> bool:
	var tw := Tower.from_list([{"id": "a", "rows": seg_rows({24: "##......####....##"}), "flip": false},
		{"id": "a", "rows": seg_rows(), "flip": false}, {"id": "a", "rows": seg_rows(), "flip": false},
		{"id": "a", "rows": seg_rows(), "flip": false}, {"id": "a", "rows": seg_rows(), "flip": false}])
	# いくつかのタップ(着くかどうかは問わない)。記録を保存して読み戻し、同じ所まで再生する
	var c: RefCounted = Climb.new(tw)
	var taps := [[0, 340, 6300], [30, 100, 6400], [80, 600, 6000], [200, 300, 5800], [260, 340, 6680]]
	var i := 0
	while c.sim_tick < 600:
		while i < taps.size() and taps[i][0] == c.sim_tick:
			c.queue_cast(taps[i][1], taps[i][2])
			i += 1
		c.step()
	var s := _fresh()
	var res: Dictionary = c.result()
	res["ticks"] = c.sim_tick
	s.record("fixed", 0, tw.name, res)
	var back: Variant = Save.new(P).ghost("fixed", 0, tw.name)
	eq(back, res["log"], "読み戻した記録が同じ")
	var c2: RefCounted = Climb.new(tw)
	var j := 0
	while c2.sim_tick < 600:
		while j < back.size() and int(back[j][0]) == c2.sim_tick:
			c2.queue_cast(int(back[j][1]), int(back[j][2]))
			j += 1
		c2.step()
	eq([c2.x, c2.y, c2.moves, c2.clock], [c.x, c.y, c.moves, c.clock], "再生すると同じ所にいる")
	return true
