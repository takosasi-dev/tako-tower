# 日付 → 通し日数 → 今日の塔の種(§9.12)。整数の計算だけ。日付は ui が端末から取って渡す(core は Time を使わない)。
# 通し日数は 2026-01-01 を 0 とし、負なら 0。作りは SlingArc の core/day_index.gd(days_from_civil)。
extends RefCounted

const B := preload("res://core/balance.gd")


# 1970-01-01 からの通し日数(H. Hinnant の days_from_civil)。
@warning_ignore("integer_division")
static func days_from_civil(y: int, m: int, d: int) -> int:
	if m <= 2:
		y -= 1
	var era := (y if y >= 0 else y - 399) / 400
	var yoe := y - era * 400
	var mp := (m + 9) % 12
	var doy := (153 * mp + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func day_index(y: int, m: int, d: int) -> int:
	return maxi(days_from_civil(y, m, d) - B.EPOCH_DAYS, 0)


static func daily_seed(day: int) -> int:
	var s := ((day + 1) * B.DAILY_MUL) & 0xFFFFFFFF
	return 1 if s == 0 else s


static func date_string(y: int, m: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, m, d]
