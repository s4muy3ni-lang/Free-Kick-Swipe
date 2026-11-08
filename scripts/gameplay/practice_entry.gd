class_name PracticeEntry
extends PracticeScene
## Escena de practica ejecutable: «Volver» regresa al partido.

func _ready() -> void:
	super._ready()
	back_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main/match.tscn"))
