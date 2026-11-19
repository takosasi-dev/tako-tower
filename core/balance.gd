# 調整値(仕様書 §9.9・INV-8)。数値はここだけに置く。
# 値は仕様書の初期値。Phase 1 で検査と bot の通しで確かめた。
extends RefCounted

const TICK_HZ := 120
const MAX_STEPS_PER_FRAME := 8
const TILE := 40
const COLS := 18
const ROWS := 32
const SEGMENTS := 5
const GOAL_ROWS := 8
const BODY_RADIUS := 16
const ARM_REACH := 320
const CAST_STEP := 4
const CAST_MIN_MOVE := 8
const CAST_LOCK_TICKS := 36
const FLY_SPEED := 1200
const GRAVITY := 2400
const FALL_MAX := 1400
const CRUMBLE_TICKS := 84
const CRUMBLE_BACK_TICKS := 360
const RESPAWN_TICKS := 48
const FALL_MISS_DEPTH := 40
const STICK_CHAIN_TICKS := 60
const CHECK_REACH := 288
const CHECK_STATE_CAP := 20000
const GHOST_MAX_MOVES := 2000

# 検査の向き: dx と dy は -CHECK_DIR_SPAN〜CHECK_DIR_SPAN の整数((0,0) を除く)。タップする点は 体 + (dx, dy) × TILE
const CHECK_DIR_SPAN := 8
# 検査で足場より上と見なす高さ(足した 8 行の足場の上面からこの px 以上、上)
const CHECK_GOAL_ABOVE := 16
# 検査の始める状態 2・3: 側壁の内側の面の中心 x と、入口の足場の上面からの高さ
const CHECK_SIDE_X_LEFT := 98
const CHECK_SIDE_X_RIGHT := 622
const CHECK_SIDE_ABOVE := 48
# 立つ時の足元の点(体の中心の真下この px)
const STAND_PROBE := 17

# 画面
const VIEW_W := 720
const VIEW_H := 1280
const CAMERA_BODY_AT := 0.6
const CAMERA_FOLLOW := 0.15
const CHECKPOINT_SHOW_SEC := 1.5
const GOAL_TO_RESULT_SEC := 0.6
const RESULT_INPUT_DELAY_SEC := 0.3
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75
const STICK_PITCH_MAX := 12
const SHAKE_PX := 4.0
const SHAKE_SEC := 0.1

# 日付: 2026-01-01 の 1970-01-01 からの通し日数
const EPOCH_DAYS := 20454
const DAILY_MUL := 2654435761
