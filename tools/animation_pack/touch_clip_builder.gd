class_name TouchClipBuilder
extends RefCounted
## Crea clips de TOQUE de conduccion a partir del balanceo real de un ciclo de marcha del pack (sin creditos, mismo
## esqueleto del jugador). En una ventana de ~0.3 s antes del apoyo, la pierna del ciclo se lleva con IK de dos huesos
## (cadera-rodilla-tobillo) hasta un punto de contacto por delante del cuerpo y casi a ras del suelo, con el empeine algo
## hacia abajo; fuera de la ventana la pierna es exactamente la del ciclo (entra y sale sin saltos). El resultado se
## reproduce como capa de una sola pierna encima de la marcha (FootballerVisual) y BallHandler aplica el impulso en el
## instante de contacto si la punta del pie llega de verdad a la pelota.

const FPS := 60.0
## Margen (s) de pose original antes y despues de la ventana del toque (para el fundido de la capa).
const PAD := 0.05
## Del espacio del jugador (yaw 0 mira a -Z, derecha +X) a (adelante, arriba, derecha) y vuelta.
static func _game(p: Vector3) -> Vector3:
	return Vector3(-p.z, p.y, p.x)

static func _player(g: Vector3) -> Vector3:
	return Vector3(g.z, g.y, -g.x)

static func _weight(t: float, t_c: float, w_in: float, w_out: float) -> float:
	if t <= t_c - w_in or t >= t_c + w_out:
		return 0.0
	if t <= t_c:
		return smoothstep(0.0, 1.0, (t - (t_c - w_in)) / w_in)
	return 1.0 - smoothstep(0.0, 1.0, (t - t_c) / w_out)

## Lleva la punta del pie de la pierna `bones` a su posicion actual + delta (metros de juego) y gira el pie `pitch`
## radianes alrededor de su eje lateral (negativo = punta hacia abajo). Mismo IK que en el juego (TouchFootIK.ik_toe).
static func _ik(sk: Skeleton3D, bones: Array, to_player: Transform3D, delta_game: Vector3, pitch: float) -> void:
	var to_skel: Transform3D = to_player.affine_inverse()
	var toe: Vector3 = PoseSampler.bone_in_skeleton(sk, bones[3]).origin
	var want_toe: Vector3 = to_skel * _player(_game(to_player * toe) + delta_game)
	TouchFootIK.ik_toe(sk, bones, want_toe, (to_skel.basis * Vector3.UP).normalized(), pitch)

## Construye el clip de toque. spec: {id, base, foot (0/1), t_c (s del ciclo base), reach (m delante), height (m),
## lateral (m a la derecha; opcional: si no, la del ciclo), pitch_deg (giro extra del empeine, negativo = hacia abajo),
## w_in, w_out (s de entrada y salida del toque)}. Devuelve {anim, meta}. vis debe estar en el arbol (anim_tree apagado).
static func build(spec: Dictionary, vis: FootballerVisual) -> Dictionary:
	var base: Animation = PackLibrary.clip(StringName(spec["base"]))
	var sk: Skeleton3D = vis.skeleton
	var bind: Dictionary = PoseSampler.bind(base, sk)
	var to_player: Transform3D = vis.global_transform.affine_inverse() * sk.global_transform
	var foot: int = int(spec["foot"])
	var bones: Array = []
	for n in TouchFootIK.LEG[foot]:
		bones.append(sk.find_bone(n))
	# El pie pasa por el punto de contacto (reach) en t_c todavia lanzado hacia delante y sigue `follow_m` metros mas
	# hasta su maxima extension en t_c + follow_s (acompanamiento); despues vuelve a la pisada del ciclo.
	var t_c: float = float(spec["t_c"])
	var t_p: float = t_c + float(spec.get("follow_s", 0.05))
	var w_in: float = float(spec["w_in"])
	var w_out: float = float(spec["w_out"])
	var t0: float = t_p - w_in - PAD
	var t1: float = t_p + w_out + PAD
	PoseSampler.apply(base, sk, bind, fposmod(t_p, base.length))
	var toe_p: Vector3 = _game(to_player * PoseSampler.bone_in_skeleton(sk, bones[3]).origin)
	var target := Vector3(float(spec["reach"]) + float(spec.get("follow_m", 0.08)), float(spec["height"]), float(spec.get("lateral", toe_p.z)))
	var delta_c: Vector3 = target - toe_p
	var pitch: float = deg_to_rad(float(spec.get("pitch_deg", 0.0)))
	var out := Animation.new()
	out.step = 1.0 / FPS
	var frames: int = int(round((t1 - t0) * FPS))
	out.length = frames / FPS
	out.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for tr in bind.keys():
		var nt: int = out.add_track(base.track_get_type(tr))
		out.track_set_path(nt, base.track_get_path(tr))
		tracks[tr] = nt
	for kf in frames + 1:
		var t: float = t0 + kf / FPS
		PoseSampler.apply(base, sk, bind, fposmod(t, base.length))
		var w: float = _weight(t, t_p, w_in, w_out)
		if w > 0.0005:
			_ik(sk, bones, to_player, delta_c * w, pitch * w)
		for tr in bind.keys():
			var b: int = bind[tr]
			if base.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(tracks[tr], kf / FPS, sk.get_bone_pose_rotation(b))
			elif base.track_get_type(tr) == Animation.TYPE_POSITION_3D:
				out.position_track_insert_key(tracks[tr], kf / FPS, sk.get_bone_pose_position(b))
	var bm: Dictionary = PackLibrary.meta(StringName(spec["base"]))
	var meta := {
		"source": "toque fusionado: %s (pie %s) + IK de pierna" % [spec["base"], "der." if foot == 1 else "izq."],
		"role": "toque", "loop": false, "mirrored": false, "duration": out.length,
		"base": String(spec["base"]), "base_time0": fposmod(t0, base.length), "base_duration": float(bm.get("duration", base.length)),
		"natural_speed": float(bm.get("natural_speed", 0.0)), "foot": foot,
		"touch_time": t_c - t0, "peak_time": t_p - t0, "reach": float(spec["reach"]), "target": target, "window": [PAD, out.length - PAD],
	}
	return {"anim": out, "meta": meta}
