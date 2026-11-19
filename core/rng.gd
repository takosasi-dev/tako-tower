# 今日の塔の並びを決める乱数(§9.2・INV-3)。xorshift32。SlingArc の core/rng.gd と同じ式(Time を使う物は写していない)。
# 端末や版で結果が変わらないよう、Godot の乱数関数は使わない。
extends RefCounted

const MASK := 0xFFFFFFFF

var state: int = 1


func _init(seed_value: int = 1) -> void:
	state = seed_value & MASK
	if state == 0:
		state = 1


func next() -> int:
	var x := state
	x = x ^ ((x << 13) & MASK)
	x = x ^ (x >> 17)
	x = x ^ ((x << 5) & MASK)
	state = x
	return x


# 0 以上 n 未満(仕様書 §9.2 の range(n))。
func next_int(n: int) -> int:
	return next() % n
