# 保存の読み書き(仕様書 §9.10・FR-23・E-13・E-14・E-15・E-20)。いつもの塔の最高・今日の塔の記録・影・設定を持つ。
# 置き場: Web はブラウザの localStorage の tako-tower/save(user:// は同じサイトのゲーム全部で 1 つなので使わない)、それ以外は user://save.json。
# 読めない・壊れている・version が違う時は既定値で始め、書けなくても止めない。作りは RootCall・ParryDuel の save_store。
extends RefCounted

const B := preload("res://core/balance.gd")

const PATH := "user://save.json"
const VERSION := 1
const WEB_KEY := "tako-tower/save"
# 使えない時は投げずに null / "no" を返す。書けたかは文字の 'ok' で返す(JS の true は 4.7.2 の Web で bool として届かない。ParryDuel v0.1.2)
const JS_READ := "(() => { try { return localStorage.getItem('%s'); } catch (e) { return null; } })()"
const JS_WRITE := "(() => { try { localStorage.setItem('%s', %s); return 'ok'; } catch (e) { return 'no'; } })()"

var path: String
var data: Dictionary = {}
var load_failed := false  # 保存があったのに読めなかった(E-13)
var write_failed := false  # 直前の書き込みが失敗した(E-14)
var _web := OS.has_feature("web")


func _init(p_path: String = PATH) -> void:
	path = p_path
	load_data()


static func default_settings() -> Dictionary:
	return {"volume": B.DEFAULT_VOLUME, "shake": true, "reduce_flash": false, "ghost": true}


static func defaults() -> Dictionary:
	return {"version": VERSION, "fixed": null, "daily": null, "settings": default_settings()}


func load_data() -> void:
	data = defaults()
	load_failed = false
	var text: Variant = _read_text()
	if text == null:
		return
	var read: Variant = parse(text)
	if read == null:
		load_failed = true
	else:
		data = read


func _read_text() -> Variant:
	if _web:
		var v: Variant = JavaScriptBridge.eval(JS_READ % WEB_KEY, true)
		return v if v is String else null
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


func _write_text(text: String) -> bool:
	if _web:
		var ok: Variant = JavaScriptBridge.eval(JS_WRITE % [WEB_KEY, JSON.stringify(text)], true)
		return ok is String and ok == "ok"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


# 保存の文字を決まった形に直す。読めない・辞書でない・version が 1 でない時は null(既定値で始める)。
# JSON の数は float で届くので、整数へ直す(前提 9)。影だけが壊れている時は、記録を残して影を空にする(E-15)。
static func parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return null
	var v: Dictionary = j.data
	if not _is_num(v.get("version")) or float(v["version"]) != float(VERSION):
		return null
	var out := defaults()
	out["fixed"] = _record(v.get("fixed"), false)
	out["daily"] = _record(v.get("daily"), true)
	var st: Variant = v.get("settings")
	if st is Dictionary:
		if _is_num(st.get("volume")) and int(st["volume"]) in B.VOLUMES:
			out["settings"]["volume"] = int(st["volume"])
		for k: String in ["shake", "reduce_flash", "ghost"]:
			if st.get(k) is bool:
				out["settings"][k] = st[k]
	return out


static func _record(v: Variant, daily: bool) -> Variant:
	if not (v is Dictionary) or not (v.get("tower") is String):
		return null
	var out := {"tower": v["tower"]}
	if daily:
		if not _is_num(v.get("day")):
			return null
		out["day"] = int(v["day"])
		out["first_ticks"] = int(v["first_ticks"]) if _is_num(v.get("first_ticks")) else null
		if not _is_num(v.get("best_ticks")):
			return out if out["first_ticks"] != null else null
	for k: String in ["best_ticks", "moves", "misses"]:
		if not _is_num(v.get(k)):
			return null
		out[k] = int(v[k])
	var splits := []
	if v.get("splits") is Array:
		for s: Variant in v["splits"]:
			if _is_num(s):
				splits.append(int(s))
	out["splits"] = splits if splits.size() == B.SEGMENTS else []
	out["ghost"] = _ghost(v.get("ghost"))
	return out


# 影の記録 [[tick, wx, wy], ...]。形がおかしければ空(E-15)。
static func _ghost(v: Variant) -> Array:
	if not (v is Array) or (v as Array).size() > B.GHOST_MAX_MOVES:
		return []
	var out := []
	var prev := -1
	for m: Variant in v:
		if not (m is Array) or (m as Array).size() != 3 or not (_is_num(m[0]) and _is_num(m[1]) and _is_num(m[2])):
			return []
		if int(m[0]) < prev:
			return []
		prev = int(m[0])
		out.append([int(m[0]), int(m[1]), int(m[2])])
	return out


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


static func _faster(a: Variant, b: Variant) -> Variant:
	if not (a is Dictionary) or not a.has("best_ticks"):
		return b
	if not (b is Dictionary) or not b.has("best_ticks"):
		return a
	return b if int(b["best_ticks"]) < int(a["best_ticks"]) else a


# 書く直前に今ある保存を読み直して合わせる(同じブラウザの別のタブが先に書いた記録を消さない)。
func _merge_from_disk() -> void:
	var text: Variant = _read_text()
	var disk: Variant = parse(text) if text != null else null
	if disk == null:
		return
	if disk["fixed"] is Dictionary and (not (data["fixed"] is Dictionary) or disk["fixed"]["tower"] == data["fixed"]["tower"]):
		data["fixed"] = _faster(data["fixed"], disk["fixed"])
	var mine: Variant = data["daily"]
	var theirs: Variant = disk["daily"]
	if theirs is Dictionary:
		if not (mine is Dictionary) or int(theirs["day"]) > int(mine["day"]):
			data["daily"] = theirs
		elif int(theirs["day"]) == int(mine["day"]):
			var merged: Dictionary = _faster(mine, theirs).duplicate()
			merged["first_ticks"] = theirs["first_ticks"] if theirs["first_ticks"] != null else mine["first_ticks"]
			data["daily"] = merged


func save_data() -> bool:
	_merge_from_disk()
	write_failed = not _write_text(JSON.stringify(data, "", false))
	return not write_failed


# 入口ごとの記録。今日の塔は日付が違えば null。
func best(kind: String, day: int = -1) -> Variant:
	if kind == "fixed":
		return data["fixed"]
	var d: Variant = data["daily"]
	if d is Dictionary and int(d["day"]) == day:
		return d
	return null


# 影に使う記録(塔の名前が違う・空なら null。E-15)。
func ghost(kind: String, day: int, tower_name: String) -> Variant:
	var r: Variant = best(kind, day)
	if not (r is Dictionary) or r.get("tower") != tower_name or (r.get("ghost", []) as Array).is_empty():
		return null
	return r["ghost"]


# 結果画面に入った時に呼ぶ(FR-23)。kind は "fixed" / "daily"。
# { prev (前の最高の記録か null), new_best, first_today, saved } を返す。
func record(kind: String, day: int, tower_name: String, result: Dictionary) -> Dictionary:
	var log: Array = result["log"]
	var rec := {"tower": tower_name, "best_ticks": int(result["ticks"]), "moves": int(result["moves"]),
		"misses": int(result["misses"]), "splits": (result["splits"] as Array).duplicate(),
		"ghost": log.duplicate(true) if log.size() <= B.GHOST_MAX_MOVES else []}  # E-20
	var out := {"prev": null, "new_best": false, "first_today": false, "saved": true}
	if kind == "fixed":
		var cur: Variant = data["fixed"]
		if cur is Dictionary and cur["tower"] != tower_name:
			cur = null
		out["prev"] = cur
		out["new_best"] = cur == null or rec["best_ticks"] < int(cur["best_ticks"])
		if out["new_best"]:
			data["fixed"] = rec
	else:
		var stored: Variant = data["daily"]
		if stored is Dictionary and int(stored["day"]) > day:
			return out  # 日付をまたいだ古い日の回(E-17)。新しい日の記録を置き換えない
		var today: Variant = stored if stored is Dictionary and int(stored["day"]) == day else null
		var has_best: bool = today is Dictionary and today.has("best_ticks")
		out["prev"] = today if has_best else null
		out["new_best"] = not has_best or rec["best_ticks"] < int(today["best_ticks"])
		var first: Variant = today["first_ticks"] if today is Dictionary else null
		if first == null:
			first = rec["best_ticks"]
			out["first_today"] = true
		if out["new_best"]:
			today = rec.duplicate()
		today["day"] = day
		today["first_ticks"] = first
		data["daily"] = today
	out["saved"] = save_data()
	return out


func settings() -> Dictionary:
	return data["settings"]


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_data()
