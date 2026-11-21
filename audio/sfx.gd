# 効果音の再生(仕様書 §9.13・FR-28)。assets/sfx/*.wav を読み、プレイヤーを順繰りに使って重ねて鳴らす。
# 音量 0 か、unlock() の前(最初の入力の前)なら鳴らさない。読めないファイルは音なしで続ける。作りは RootCall の audio/sfx.gd。
extends Node

const NAMES: Array = ["cast", "stick", "cast_miss", "land", "crack", "crumble", "miss", "checkpoint", "goal"]
const VOICES := 8

var volume := 75  # 0〜100
var unlocked := false
var played := 0  # 再生を始めた回数(テストが読む)

var _streams := {}
var _db := 0.0
var _ui_at := -100000  # 最後に UI の音を鳴らした時刻(ms)
var _voices: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name: String in NAMES:
		var path := "res://assets/sfx/" + sound_name + ".wav"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_streams[sound_name] = stream
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	set_volume(volume)


func unlock() -> void:
	unlocked = true


# 25〜100 は 2 乗で dB に直す(100 → 0 dB、75 → −5 dB、50 → −12 dB、25 → −24 dB)。0 は鳴らさない。
func set_volume(percent: int) -> void:
	volume = clampi(percent, 0, 100)
	_db = linear_to_db(pow(volume / 100.0, 2.0)) if volume > 0 else -80.0
	for voice in _voices:
		voice.volume_db = _db


# 画面の部品の小さな音(v0.3.0)。新しい音は作らず、今の 9 個を高く・小さく鳴らす(仕様の「効果音 9 種以内」)。
# move はフォーカスが動いた時(押した直後と画面に入った時のフォーカスでは鳴らさない)、ok は押した時。
func ui(kind: String) -> void:
	var now := Time.get_ticks_msec()
	if kind == "hush":  # これから動くフォーカスは画面が置く物なので鳴らさない
		_ui_at = now
		return
	if kind == "move":
		if now - _ui_at < 150:
			return
		play("cast", 12, -10.0)
	else:
		play("stick", 5, -6.0)
	_ui_at = now


# semitones だけ高くして鳴らす(張り付く音の連続)。gain_db で音量の設定から下げる。
func play(sound_name: String, semitones: int = 0, gain_db := 0.0) -> void:
	if not unlocked or volume <= 0 or not _streams.has(sound_name):
		return
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = _streams[sound_name]
	voice.pitch_scale = pow(2.0, semitones / 12.0)
	voice.volume_db = _db + gain_db
	voice.play()
	played += 1
