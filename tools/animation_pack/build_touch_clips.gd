extends Node
## Construye assets/animations/touch_clips.res: clips de toque de conduccion fusionados a partir de los ciclos de
## marcha con pelota del pack (TouchClipBuilder). Cada clip lleva set_meta("pack", {...}) con el contacto MEDIDO sobre
## el esqueleto (instante, pie, posicion de la punta, velocidad del pie) y los datos de su ciclo base.
## Uso: godot --headless --path . res://tools/animation_pack/build_touch_clips.tscn

const OUT := "res://assets/animations/touch_clips.res"

## t_c: instante del ciclo base (s) en el que la punta llega al punto de contacto (final del balanceo, antes del
## apoyo). reach/height/lateral: punto de contacto de la punta en metros de juego (adelante, arriba, derecha).
## Si el ciclo base adelanta ese pie mas de una vez (Dribble_2 y el sprint de dos ciclos), se crea ademas un clip por
## cada otro balanceo (sufijo _2, ...) con el mismo contacto, desplazado al instante equivalente de ese balanceo: el
## toque se dispara en fase con el ciclo (BallHandler) y cada balanceo tiene su propia cadera.
## Cada balanceo tiene ademas variantes de alcance (REACH_VARIANTS): la punta solo va baja al final del balanceo, asi que
## un solo alcance deja una franja estrecha de distancias de pelota en la que el pie la encuentra a ras; con las
## variantes el plan del toque elige la que encuentra la pelota donde esta.
const SPECS := [
	{"id": "Touch_Jog_R", "base": "Dribble_2", "foot": 1, "t_c": 0.55, "reach": 0.40, "height": 0.04, "lateral": 0.09, "pitch_deg": -35.0, "w_in": 0.20, "w_out": 0.14, "follow_s": 0.04, "follow_m": 0.04},
	{"id": "Touch_Jog_L", "base": "Dribble_2", "foot": 0, "t_c": 0.14, "reach": 0.40, "height": 0.04, "lateral": -0.09, "pitch_deg": -35.0, "w_in": 0.20, "w_out": 0.14, "follow_s": 0.04, "follow_m": 0.04},
	{"id": "Touch_Run_R", "base": "Running_inplace", "foot": 1, "t_c": 0.53, "reach": 0.46, "height": 0.04, "lateral": 0.09, "pitch_deg": -38.0, "w_in": 0.18, "w_out": 0.12, "follow_s": 0.04, "follow_m": 0.04},
	{"id": "Touch_Run_L", "base": "Running_inplace", "foot": 0, "t_c": 0.115, "reach": 0.46, "height": 0.04, "lateral": -0.09, "pitch_deg": -38.0, "w_in": 0.18, "w_out": 0.12, "follow_s": 0.04, "follow_m": 0.04},
	{"id": "Touch_Sprint_R", "base": "Two_Cycle_Sprint_inplace", "foot": 1, "t_c": 0.85, "reach": 0.50, "height": 0.04, "lateral": 0.08, "pitch_deg": -40.0, "w_in": 0.15, "w_out": 0.10, "follow_s": 0.03, "follow_m": 0.04},
	{"id": "Touch_Sprint_L", "base": "Two_Cycle_Sprint_inplace", "foot": 0, "t_c": 0.61, "reach": 0.50, "height": 0.04, "lateral": -0.08, "pitch_deg": -40.0, "w_in": 0.15, "w_out": 0.10, "follow_s": 0.03, "follow_m": 0.04},
]

## Instantes (s) en que la punta del pie `foot` cruza el plano del cuerpo hacia delante (inicio de cada balanceo).
static func _swing_starts(base: StringName, foot: int, vis: FootballerVisual) -> Array[float]:
	var bs: Dictionary = FootTrajectory.sample(PackLibrary.clip(base), vis)
	var out: Array[float] = []
	var n: int = int(bs["frames"])
	for k in n:
		var a0: Vector3 = bs["toe"][foot][k]
		var a1: Vector3 = bs["toe"][foot][(k + 1) % n]
		if a0.x < 0.0 and a1.x >= 0.0:
			out.append((k + a0.x / (a0.x - a1.x)) * float(bs["dt"]))
	return out

## La spec pedida y una copia por cada otro balanceo del mismo pie en el ciclo base.
static func _swing_specs(spec: Dictionary, vis: FootballerVisual) -> Array:
	var out: Array = [spec]
	var base: StringName = StringName(spec["base"])
	var length: float = PackLibrary.clip(base).length
	var starts: Array[float] = _swing_starts(base, int(spec["foot"]), vis)
	if starts.size() < 2:
		return out
	var t_c: float = float(spec["t_c"])
	# Balanceo al que pertenece t_c: el ultimo inicio anterior (en el ciclo).
	var own: int = 0
	var best: float = INF
	for i in starts.size():
		var back: float = fposmod(t_c - starts[i], length)
		if back < best:
			best = back
			own = i
	var n := 2
	for i in starts.size():
		if i == own:
			continue
		var s2: Dictionary = spec.duplicate()
		s2["id"] = "%s_%d" % [spec["id"], n]
		s2["t_c"] = fposmod(starts[i] + best, length)
		out.append(s2)
		n += 1
	return out

## Sufijo del clip y metros que se suman al alcance (reach) de la spec.
const REACH_VARIANTS := [["_Close", -0.18], ["_Near", -0.10], ["_Far", 0.05]]

func _ready() -> void:
	PackLibrary.reload()
	var vis := FootballerVisual.new()
	add_child(vis)
	vis.build(FootballerVisual.default_kit(0))
	vis.anim_tree.active = false
	var lib := AnimationLibrary.new()
	var specs: Array = []
	for spec in SPECS:
		for sw in _swing_specs(spec, vis):
			specs.append(sw)
			for rv in REACH_VARIANTS:
				var v: Dictionary = sw.duplicate()
				v["id"] = String(sw["id"]) + String(rv[0])
				v["reach"] = float(sw["reach"]) + float(rv[1])
				specs.append(v)
	for spec in specs:
		var r: Dictionary = TouchClipBuilder.build(spec, vis)
		var anim: Animation = r["anim"]
		var meta: Dictionary = r["meta"]
		# Contacto medido en el clip resultante (no el pedido): posicion y velocidad de la punta en el instante del toque.
		var s: Dictionary = FootTrajectory.sample(anim, vis)
		var dt: float = s["dt"]
		var foot: int = int(meta["foot"])
		var i: int = -1
		var i_max: int = 0
		for k in range(1, int(s["frames"])):
			if (s["toe"][foot][k] as Vector3).x > (s["toe"][foot][i_max] as Vector3).x:
				i_max = k
			if i < 0 and (s["toe"][foot][k] as Vector3).x >= float(meta["reach"]) and (s["toe"][foot][k - 1] as Vector3).x < float(meta["reach"]):
				i = k
		# Si la pierna no llega al alcance pedido (ya estirada): una variante se omite (repetiria la base); el clip base
		# toma como contacto su maxima extension.
		if i < 0:
			if String(spec["id"]).ends_with("_Close") or String(spec["id"]).ends_with("_Near") or String(spec["id"]).ends_with("_Far"):
				print("TOQUE %-22s omitido: la punta no llega a %.2f m (maximo %.2f)" % [spec["id"], float(meta["reach"]), (s["toe"][foot][i_max] as Vector3).x])
				continue
			i = i_max
		meta["touch_time"] = i * dt
		var toe: Vector3 = s["toe"][foot][i]
		var prev: Vector3 = s["toe"][foot][maxi(i - 1, 0)]
		var nxt: Vector3 = s["toe"][foot][mini(i + 1, int(s["frames"]))]
		var v: Vector3 = (nxt - prev) / (2.0 * dt)
		var path := PackedVector3Array()
		for k in int(s["frames"]) + 1:
			path.append(s["toe"][foot][k])
		meta["contact"] = {"time": float(meta["touch_time"]), "foot": foot, "pos": toe, "speed": v.length(), "vel": v,
			"path": path, "path_t0": 0.0, "path_dt": dt}
		# Inicio del toque (para dispararlo cuando el pie vivo pasa por ahi) y periodo del balanceo de ese pie en su
		# ciclo base (cuantas veces adelanta ese pie por ciclo: el siguiente toque del mismo pie llega un periodo despues).
		meta["start_toe"] = s["toe"][foot][0]
		meta["start_toe_vel"] = ((s["toe"][foot][1] as Vector3) - (s["toe"][foot][0] as Vector3)) / dt
		# Hasta el siguiente balanceo del mismo pie (el siguiente toque de ese pie): del inicio de este balanceo al
		# siguiente inicio en el ciclo base.
		var blen: float = PackLibrary.clip(StringName(spec["base"])).length
		var starts: Array[float] = _swing_starts(StringName(spec["base"]), foot, vis)
		var t_c: float = float(spec["t_c"])
		var own_back: float = INF
		var own_i := 0
		for si in starts.size():
			var back: float = fposmod(t_c - starts[si], blen)
			if back < own_back:
				own_back = back
				own_i = si
		var gap: float = blen
		if starts.size() > 1:
			gap = fposmod(starts[(own_i + 1) % starts.size()] - starts[own_i], blen)
		meta["swing_period"] = gap * float(meta["base_duration"]) / blen
		anim.set_meta("pack", meta)
		lib.add_animation(StringName(spec["id"]), anim)
		var min_h := INF
		var max_fwd := -INF
		for k in int(s["frames"]) + 1:
			min_h = minf(min_h, (s["toe"][foot][k] as Vector3).y)
			max_fwd = maxf(max_fwd, (s["toe"][foot][k] as Vector3).x)
		print("TOQUE %-22s base %-25s pie %s: contacto t=%.3f punta %s, pie a %.2f m/s relativo al cuerpo (adelante %+.2f); extension max %.2f m; punta min %.3f m; dur %.2f s; inicio %s; periodo del pie %.3f s" % [
			spec["id"], spec["base"], "der" if foot == 1 else "izq", float(meta["touch_time"]), toe, v.length(), v.x, max_fwd, min_h, anim.length, meta["start_toe"], meta["swing_period"]])
	var err: int = ResourceSaver.save(lib, OUT)
	print("TOQUES guardados en %s (error=%d, %d clips)" % [OUT, err, lib.get_animation_list().size()])
	get_tree().quit()
