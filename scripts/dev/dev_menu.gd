class_name DevMenu
extends Control
## Menu de desarrollo de la reforma (tiros libres y penales). Es la entrada del juego mientras dura la reforma: desde aqui se
## abre el banco de pruebas de animaciones (Fase 1: comparar JSON, Mixamo y Mocap). El modo de futbol 5 se quito de esta
## rama (decision del usuario, 2026-11-07); los modos de tiros libres y penales se agregan aqui cuando existan.
## Horizontal, 16:9; se adapta a otras proporciones sin deformar.

const SCENE := "res://scenes/dev/dev_menu.tscn"
const BENCH_SCENE := "res://scenes/dev/anim_bank_bench.tscn"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.16, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	var title := Label.new()
	title.text = "MENÚ DE DESARROLLO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Reforma: tiros libres y penales — Fase 1 (comparación de bancos de animación)"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	vb.add_child(sub)
	vb.add_child(_button("Banco de pruebas de animaciones\nJSON original · Mixamo · Mocap", BENCH_SCENE))
	GraphicsSettings.apply()

func _button(text: String, scene: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(620, 92)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func() -> void: open(scene))
	return b

func open(scene: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)
