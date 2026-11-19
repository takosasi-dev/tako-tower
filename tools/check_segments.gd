# 全区画の検査(§9.6 の (a)(b)(c)(d))を回し、区画ごとの結果・状態数・秒数を出す。1 個でも落ちたら終了コード 1。
# 実行: python tools/gd.py run res://tools/check_segments.gd [JSON のパス] [-- span=N] [only=s01,s02] [path]
extends SceneTree

const B := preload("res://core/balance.gd")
const Store := preload("res://core/segment_store.gd")
const Check := preload("res://core/segment_check.gd")


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var file := Store.PATH
	var span := B.CHECK_DIR_SPAN
	var only := []
	var show_path := false
	for a: String in args:
		if a.begins_with("span="):
			span = int(a.substr(5))
		elif a.begins_with("only="):
			only = a.substr(5).split(",")
		elif a == "path":
			show_path = true
		elif a.begins_with("res://"):
			file = a
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(file)) != OK:
		print("読めない: ", file)
		quit(1)
		return
	var dir_list := Check.dirs(span)
	print("向き %d 通り、届く距離 %d px、状態の上限 %d" % [dir_list.size(), B.CHECK_REACH, B.CHECK_STATE_CAP])
	var failed := 0
	var total_usec := 0
	for s: Dictionary in j.data["segments"]:
		var seg := {"id": s["id"], "tier": int(s["tier"]), "rows": Array(s["rows"])}
		if not only.is_empty() and not only.has(seg["id"]):
			continue
		for flip: bool in [false, true]:
			var rows: Array = Store.flip_rows(seg["rows"]) if flip else seg["rows"]
			var name: String = seg["id"] + ("r" if flip else "")
			var errs := Store.shape_errors({"id": name, "tier": seg["tier"], "rows": rows})
			if not errs.is_empty():
				failed += 1
				print("NG  %s 形: %s" % [name, ", ".join(errs)])
				continue
			var t0 := Time.get_ticks_usec()
			var r := Check.check(rows, B.CHECK_REACH, dir_list)
			var usec := Time.get_ticks_usec() - t0
			total_usec += usec
			var parts := []
			for st: Dictionary in r["starts"]:
				parts.append("%s 状態 %d 最上 y %d%s" % ["通" if st["ok"] else "落", st["states"], int(st["best_y"]),
					" 上限" if st.get("capped", false) else ""])
			print("%s  %s %.1f 秒  [%s]" % ["OK" if r["ok"] else "NG", name, usec / 1e6, " / ".join(parts)])
			if show_path:
				for st: Dictionary in r["starts"]:
					print("      道: ", st["path"], " 終 ", st.get("end", ""))
			if not r["ok"]:
				failed += 1
	print("合計 %.1f 秒、落ちた %d" % [total_usec / 1e6, failed])
	quit(1 if failed > 0 else 0)
