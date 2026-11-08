class_name FootTrajectory
extends RefCounted
## Trayectoria MEDIDA de los pies de un clip sobre el esqueleto del futbolista (no supuesta por el nombre del clip).
## Recorre el clip a 60 Hz con PoseSampler (pose compuesta a mano: funciona sin render) y devuelve, por pie, la punta
## (ToeBase) y el tobillo (Foot) en metros de juego como (adelante, arriba, derecha) respecto al origen del jugador.
## Con la velocidad del cuerpo del clip detecta:
##  - empujes: punta baja, por delante del cuerpo y avanzando SOBRE EL SUELO mas rapido que el cuerpo (un pie asi puede
##    impulsar una pelota hacia delante: es un toque de conduccion visible);
##  - apoyos: punta en el suelo y casi quieta sobre el suelo (pisada de la zancada).
## Lo usan el inventario de animaciones (tests/test_animation_inventory.gd) y la conduccion (instantes de toque del clip).

const RATE := 60.0
## Altura (m) maxima de la punta para contar como pie bajo (pelota de 0.11 m de radio).
const LOW_TOE := 0.15
## Distancia (m) minima por delante del origen del jugador para que la punta pueda empujar la pelota hacia delante.
const AHEAD := 0.15
## Margen (m/s) sobre la velocidad del cuerpo para que el pie empuje (si no, la pelota no sale por delante del jugador).
const PUSH_MARGIN := 0.5
## Altura (m) y velocidad sobre el suelo (m/s) maximas de un apoyo.
const PLANT_TOE := 0.08
const PLANT_SPEED := 0.6

## Velocidad (m/s) del cuerpo del clip: la natural medida si es una marcha en el sitio, si no la de su raiz.
static func body_speed(meta: Dictionary) -> float:
	var nat: float = float(meta.get("natural_speed", 0.0))
	if nat > 0.0:
		return nat
	var dur: float = maxf(float(meta.get("duration", 1.0)), 0.01)
	var rt = meta.get("root_total", Vector2.ZERO)
	return (rt as Vector2).length() / dur if rt is Vector2 else 0.0

## Muestras del clip: {"dt", "frames", "toe": [[Vector3 por fotograma] x2 pies], "ankle": [...]}. vis debe estar en el
## arbol (se usa la transformacion del esqueleto respecto al jugador). Deja el esqueleto en la ultima pose.
static func sample(anim: Animation, vis: FootballerVisual) -> Dictionary:
	var sk: Skeleton3D = vis.skeleton
	var bind: Dictionary = PoseSampler.bind(anim, sk)
	var toes := [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
	var ankles := [sk.find_bone("mixamorig_LeftFoot"), sk.find_bone("mixamorig_RightFoot")]
	var to_player: Transform3D = vis.global_transform.affine_inverse() * sk.global_transform
	var frames: int = maxi(int(round(anim.length * RATE)), 2)
	var dt: float = anim.length / float(frames)
	var toe: Array = [[], []]
	var ankle: Array = [[], []]
	for i in frames + 1:
		PoseSampler.apply(anim, sk, bind, minf(i * dt, anim.length))
		for f in 2:
			toe[f].append(_game(to_player * PoseSampler.bone_in_skeleton(sk, toes[f]).origin))
			ankle[f].append(_game(to_player * PoseSampler.bone_in_skeleton(sk, ankles[f]).origin))
	return {"dt": dt, "frames": frames, "toe": toe, "ankle": ankle, "bound": bind.size(), "tracks": anim.get_track_count()}

## Del espacio del jugador (yaw 0 mira a -Z, derecha +X) a (adelante, arriba, derecha).
static func _game(p: Vector3) -> Vector3:
	return Vector3(-p.z, p.y, p.x)

## Analiza las muestras con la velocidad del cuerpo vb (m/s): empujes y apoyos por pie, alcances y alturas.
static func analyze(s: Dictionary, vb: float) -> Dictionary:
	var dt: float = s["dt"]
	var n: int = int(s["frames"]) + 1
	var pushes: Array = []
	var plants: Array = []
	var feet: Array = []
	for f in 2:
		var toe: Array = s["toe"][f]
		var min_h := INF
		var max_fwd := -INF
		var max_fwd_low := -INF
		var in_push := false
		var ev := {}
		for i in n:
			var p: Vector3 = toe[i]
			var prev: Vector3 = toe[maxi(i - 1, 0)]
			var nxt: Vector3 = toe[mini(i + 1, n - 1)]
			var steps: int = mini(i + 1, n - 1) - maxi(i - 1, 0)
			var vr: float = (nxt.x - prev.x) / maxf(steps * dt, 0.0001)
			var vg: float = vr + vb   # avance del pie sobre el suelo
			min_h = minf(min_h, p.y)
			max_fwd = maxf(max_fwd, p.x)
			if p.y < LOW_TOE:
				max_fwd_low = maxf(max_fwd_low, p.x)
			var pushing: bool = p.y < LOW_TOE and p.x > AHEAD and vg > vb + PUSH_MARGIN
			var ank: Vector3 = s["ankle"][f][i]
			# angulo del pie sobre el suelo (tobillo -> punta) respecto al frente: 0 = empeine/punta hacia delante,
			# positivo = punta hacia fuera (toque con el interior), negativo = hacia dentro (exterior)
			var foot_dir := Vector2(p.x - ank.x, (p.z - ank.z) * (1.0 if f == 1 else -1.0))
			var yaw_deg: float = rad_to_deg(atan2(foot_dir.y, foot_dir.x))
			if pushing:
				if not in_push:
					ev = {"foot": f, "t0": i * dt, "t1": i * dt, "t": i * dt, "fwd": p.x, "up": p.y, "right": p.z, "vg": vg, "yaw": yaw_deg}
					in_push = true
				ev["t1"] = i * dt
				if p.x > float(ev["fwd"]):
					ev["fwd"] = p.x
					ev["t"] = i * dt
					ev["up"] = p.y
					ev["right"] = p.z
					ev["yaw"] = yaw_deg
				ev["vg"] = maxf(float(ev["vg"]), vg)
			elif in_push:
				pushes.append(ev)
				in_push = false
			# apoyo: minimo local de altura, en el suelo y casi quieto sobre el suelo
			if i > 0 and i < n - 1 and p.y < PLANT_TOE and p.y <= prev.y and p.y < nxt.y and absf(vg) < PLANT_SPEED:
				plants.append({"foot": f, "t": i * dt, "fwd": p.x, "right": p.z})
		if in_push:
			pushes.append(ev)
		var heel_max := 0.0
		for i in n:
			heel_max = maxf(heel_max, (s["ankle"][f][i] as Vector3).y)
		feet.append({"min_h": min_h, "max_fwd": max_fwd, "max_fwd_low": max_fwd_low if max_fwd_low > -INF else -1.0, "heel_max": heel_max})
	pushes.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	plants.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	return {"pushes": pushes, "plants": plants, "feet": feet, "vb": vb}

## --- Criterios de un clip de CONDUCCION en carrera (toques integrados) ---------------------------------------------
## Medidos en el video de referencia (juego comercial) y en las zancadas del pack: una zancada normal apoya la punta a
## 0.16-0.28 m del cuerpo (sprint 0.27-0.39 m); un toque de conduccion lleva el pie MAS ALLA de la zancada hacia la pelota
## que va delante (0.3-1.2 m en el video) y la empuja: punta baja y mas rapida que el cuerpo. En el video hay un toque cada
## 0.60-0.66 s y la pelota no cambia de lado.
const TOUCH_MIN_REACH := 0.40
const TOUCH_MAX_TOE := 0.12
const TOUCH_MIN_PUSH := 1.5
const TOUCH_PERIOD_MIN := 0.35
const TOUCH_PERIOD_MAX := 1.0
const TOUCH_MAX_LATERAL := 0.20

## Toques de conduccion del clip: empujes que pasan del alcance de una zancada (ver constantes de arriba).
static func dribble_touches(a: Dictionary) -> Array:
	var out: Array = []
	var vb: float = float(a["vb"])
	for e in a["pushes"]:
		if float(e["fwd"]) >= TOUCH_MIN_REACH and float(e["up"]) <= TOUCH_MAX_TOE and float(e["vg"]) >= vb + TOUCH_MIN_PUSH:
			out.append(e)
	return out

## Evalua si un clip sirve como conduccion en carrera. Devuelve {ok, motivos[], toques, periodo}.
static func dribble_verdict(a: Dictionary, meta: Dictionary) -> Dictionary:
	var reasons: Array = []
	var touches: Array = dribble_touches(a)
	var dur: float = float(meta.get("duration", 1.0))
	if not bool(meta.get("loop", false)):
		reasons.append("no es un bucle")
	if float(a["vb"]) < 1.5:
		reasons.append("el cuerpo no avanza (%.2f m/s)" % float(a["vb"]))
	if touches.is_empty():
		var best := 0.0
		for e in a["pushes"]:
			best = maxf(best, float(e["fwd"]))
		reasons.append("ningun toque pasa de la zancada (alcance maximo del pie bajo %.2f m < %.2f m)" % [best, TOUCH_MIN_REACH])
	var period: float = dur / float(touches.size()) if not touches.is_empty() else -1.0
	if not touches.is_empty() and (period < TOUCH_PERIOD_MIN or period > TOUCH_PERIOD_MAX):
		reasons.append("un toque cada %.2f s (fuera de %.2f-%.2f s)" % [period, TOUCH_PERIOD_MIN, TOUCH_PERIOD_MAX])
	for e in touches:
		if absf(float(e["right"])) > TOUCH_MAX_LATERAL:
			reasons.append("toque a %.2f s demasiado al costado (%.2f m)" % [float(e["t"]), absf(float(e["right"]))])
	return {"ok": reasons.is_empty(), "reasons": reasons, "touches": touches.size(), "period": period}
