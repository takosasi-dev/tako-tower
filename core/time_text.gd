# tick → 秒の文字(§9.8)。表示する秒 = floor(tick × 100 ÷ 120) ÷ 100 を小数 2 桁で。差は − / + を付ける。
# 整数だけで作る(小数の丸めで 1 違うのを避ける)。
extends RefCounted

const B := preload("res://core/balance.gd")


@warning_ignore("integer_division")
static func secs(tick: int) -> String:
	var c := maxi(tick, 0) * 100 / B.TICK_HZ
	return "%d.%02d" % [c / 100, c % 100]


# 差の表示。速ければ「−0.42」、遅ければ「+1.10」、同じなら「0.00」。
static func diff(tick: int) -> String:
	if tick == 0:
		return "0.00"
	return ("−" if tick < 0 else "+") + secs(absi(tick))


# 区切り(入った tick の列)から、区画ごとにかかった tick。
static func lap_ticks(splits: Array) -> Array:
	var out := []
	var prev := 0
	for s: Variant in splits:
		out.append(int(s) - prev)
		prev = int(s)
	return out
