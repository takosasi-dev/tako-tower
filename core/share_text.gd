# 共有する文字(§9.11)。日付・入口・時間・手数・ミス数・URL だけを入れる。
extends RefCounted

const S := preload("res://core/strings.gd")
const T := preload("res://core/time_text.gd")


# kind: "fixed" / "daily"。first は今日の塔の 1 回目か。
static func make(date: String, kind: String, first: bool, ticks: int, moves: int, misses: int) -> String:
	var label := S.SHARE_FIXED
	if kind == "daily":
		label = S.SHARE_DAILY_FIRST if first else S.SHARE_DAILY
	return "\n".join([S.SHARE_HEAD % [date, label], S.SHARE_BODY % [T.secs(ticks), moves, misses], S.URL])
