# ui/kit.gd の make_theme() を ui/theme.tres に書く(project の gui/theme/custom が読む)。Kit の色や形を変えたら回し直す。
#     python tools/gd.py run res://tools/make_theme.gd
extends SceneTree

const Kit := preload("res://ui/kit.gd")
const OUT := "res://ui/theme.tres"


func _initialize() -> void:
	var err := ResourceSaver.save(Kit.make_theme(), OUT)
	print("%s: %s" % [OUT, "書いた" if err == OK else "書けない(%d)" % err])
	quit(0 if err == OK else 1)
