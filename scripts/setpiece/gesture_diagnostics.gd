class_name GestureDiagnostics
extends PanelContainer
## Panel de diagnostico y calibracion del disparo por trazo (se abre con «Diag.» en el juego): muestra lo medido del ultimo
## gesto (velocidad, largo, potencia, altura, efecto, precision, tipo), el golpeo elegido y la velocidad REAL con la que salio
## la pelota; permite cambiar los coeficientes de GestureTuning en caliente (sin recompilar), guardarlos o volver a los de
## por defecto, y comparar trazos sinteticos (cortos, largos, lentos, rapidos, rectos, curvos, irregulares).

signal compare_requested

var _metrics: Label
var _sliders: VBoxContainer
var _value_labels: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -470
	offset_right = -10
	offset_top = 84
	offset_bottom = -10
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.9)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	var title := Label.new()
	title.text = "DIAGNÓSTICO DEL TRAZO"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	vb.add_child(title)
	_metrics = Label.new()
	_metrics.add_theme_font_size_override("font_size", 15)
	_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metrics.text = "Hacé un trazo para ver sus datos."
	vb.add_child(_metrics)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	for b in [["Comparar trazos", func() -> void: compare_requested.emit()],
			["Guardar", func() -> void: GestureTuning.save_current()],
			["Por defecto", func() -> void: GestureTuning.reset_current(); _refresh_sliders()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 15)
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(b[1])
		row.add_child(btn)
	var sub := Label.new()
	sub.text = "Coeficientes (se aplican al próximo trazo):"
	sub.add_theme_font_size_override("font_size", 15)
	vb.add_child(sub)
	_sliders = VBoxContainer.new()
	vb.add_child(_sliders)
	_build_sliders()

func _build_sliders() -> void:
	for c in _sliders.get_children():
		c.queue_free()
	_value_labels.clear()
	var t: GestureTuning = GestureTuning.current()
	for e in GestureTuning.EDITABLE:
		var name_: String = e[0]
		var hb := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(170, 0)
		l.add_theme_font_size_override("font_size", 14)
		hb.add_child(l)
		var s := HSlider.new()
		s.min_value = e[1]
		s.max_value = e[2]
		s.step = e[3]
		s.value = float(t.get(name_))
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(0, 32)
		s.focus_mode = Control.FOCUS_NONE
		s.value_changed.connect(func(v: float) -> void:
			GestureTuning.current().set(name_, v)
			l.text = "%s = %s" % [name_, str(snappedf(v, float(e[3])))])
		hb.add_child(s)
		l.text = "%s = %s" % [name_, str(snappedf(s.value, float(e[3])))]
		_value_labels[name_] = l
		_sliders.add_child(hb)

func _refresh_sliders() -> void:
	_build_sliders()

## Datos del ultimo gesto y del tiro.
func show_shot(f: Dictionary, p: ShotParams, clip_id: String, launch_speed: float) -> void:
	var lines: PackedStringArray = []
	lines.append("Velocidad del trazo: media %.2f · máx. %.2f alt/s" % [float(f.get("avg_speed", 0.0)), float(f.get("peak_speed", 0.0))])
	lines.append("Largo: %.2f alt · duración %.2f s · muestras %d" % [float(f.get("length", 0.0)), float(f.get("duration", 0.0)), int(f.get("samples", 0))])
	lines.append("Curvatura %.3f · giro %.0f° · suavidad %.2f" % [float(f.get("curvature", 0.0)), float(f.get("turn_deg", 0.0)), float(f.get("smoothness", 1.0))])
	if p != null:
		lines.append("Potencia: %.2f → %.1f m/s" % [p.power, p.speed])
		lines.append("Altura de llegada: %.2f m · ángulo de salida %.1f°" % [p.target.y, p.launch_angle])
		lines.append("Efecto lateral: %.1f rad/s" % p.lateral_spin)
		lines.append("Precisión: %.2f (error %.2f°)" % [p.accuracy, p.error_deg])
		lines.append("Tipo: %s · previsto: %s" % [p.gesture_type, p.predicted_class])
	if clip_id != "":
		lines.append("Golpeo: %s" % clip_id)
	if launch_speed >= 0.0:
		lines.append("Velocidad real de salida de la pelota: %.1f m/s" % launch_speed)
	_metrics.text = "\n".join(lines)

func show_text(t: String) -> void:
	_metrics.text = t
