extends SceneTree
## Reforma, Fase 1: compatibilidad de los tres bancos de animacion (JSON, Mixamo, Mocap) con el cuerpo comun de la
## comparacion (el humano del modo JSON, json_human.scn) frente al futbolista (player_base.glb), sobre el que se
## retargetearon Mixamo y Mocap. Solo mide: no modifica bibliotecas, clips ni cuerpos.
##
## Uso (desde la raiz del proyecto):
##   godot --headless --path . --script res://tools/reforma/bank_compat.gd -- --out docs/reforma/fase1/compatibilidad
## Salida: reposo.csv (hueso por hueso), clips.csv (clip por clip y cuerpo), resumen.json.
##
## Que se mide, sin render (las poses se componen a mano con PoseSampler):
## - Reposo: por hueso, angulo entre las rotaciones locales de reposo de los dos cuerpos y largo del hueso en cada uno.
##   Las pistas de rotacion de Godot guardan la rotacion LOCAL absoluta del hueso, asi que un clip pensado para un
##   reposo se ve distinto sobre otro si esos angulos no son cero.
## - Por clip y cuerpo: altura minima de pies y puntas en todo el clip (hundido < 0, flotando si el minimo es alto) y
##   desvio de cada articulacion entre los dos cuerpos (mismo clip, mismo instante, posiciones relativas a la cadera):
##   cuanto cambia la pose al pasar el clip de su cuerpo original al cuerpo comun.
## - Golpeos (clips con contacto medido al convertir): distancia entre la punta del pie del clip en el instante de contacto y
##   el punto de contacto guardado en sus metadatos, sobre cada cuerpo (sincronizacion del contacto).
## - Transiciones (sobre el cuerpo original): salto de pose entre el reposo del banco y el inicio del clip, y entre el final
##   del clip y el reposo (articulaciones relativas a la cadera). Mocap no tiene reposo: no se puede medir.

const BANKS := {
	"json": ["res://assets/animations/json_clips.res", "res://assets/animations/json_keeper.res", "res://assets/animations/json_scenes.res"],
	"mixamo": ["res://assets/animations/pack_clips.res", "res://assets/animations/pack_keeper.res"],
	"mocap": ["res://assets/animations/mocap_clips.res"],
}
## Cuerpo para el que se convirtio cada banco.
const NATIVE := {"json": "json_human", "mixamo": "player_base", "mocap": "player_base"}
const BODIES := {"json_human": "res://assets/characters/json/json_human.scn", "player_base": "res://assets/characters/player/player_base.glb"}
const JOINTS: Array[String] = ["mixamorig_Hips", "mixamorig_Head", "mixamorig_LeftHand", "mixamorig_RightHand", "mixamorig_LeftFoot",
	"mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
const FEET: Array[String] = ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
## Reposo de referencia de cada banco para medir transiciones ("" = el banco no tiene).
const IDLE := {"json": "jn_idle_0520", "mixamo": "Soccer_Idle", "mocap": ""}
const SCALE := 1.75
const SAMPLE_HZ := 30.0
const MAX_SAMPLES := 240

var _sk: Dictionary = {}

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = "docs/reforma/fase1/compatibilidad"
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	for key in BODIES:
		var inst: Node = (load(BODIES[key]) as PackedScene).instantiate()
		root.add_child(inst)
		_sk[key] = inst.find_child("Skeleton3D", true, false)
	var summary: Dictionary = {"reposo": _rest(out_dir + "/reposo.csv")}
	summary["bancos"] = _clips(out_dir + "/clips.csv")
	var f := FileAccess.open(out_dir + "/resumen.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, " "))
	f.close()
	print("COMPAT listo: ", out_dir)
	quit()

func _rest(path: String) -> Dictionary:
	var a: Skeleton3D = _sk["json_human"]
	var b: Skeleton3D = _sk["player_base"]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("hueso,angulo_reposo_local_grados,largo_json_human_m,largo_player_base_m,altura_json_human_m,altura_player_base_m")
	var max_ang: float = 0.0
	var angs: Array = []
	for i in a.get_bone_count():
		var n: String = a.get_bone_name(i)
		var j: int = b.find_bone(n)
		if j < 0:
			f.store_line("%s,sin hueso en player_base,,,," % n)
			continue
		var qa: Quaternion = a.get_bone_rest(i).basis.get_rotation_quaternion()
		var qb: Quaternion = b.get_bone_rest(j).basis.get_rotation_quaternion()
		var ang: float = rad_to_deg(qa.angle_to(qb))
		angs.append(ang)
		max_ang = maxf(max_ang, ang)
		f.store_line("%s,%.1f,%.3f,%.3f,%.3f,%.3f" % [n, ang, a.get_bone_rest(i).origin.length(), b.get_bone_rest(j).origin.length(),
			a.get_bone_global_rest(i).origin.y, b.get_bone_global_rest(j).origin.y])
	f.close()
	angs.sort()
	return {"huesos": angs.size(), "angulo_max_grados": max_ang, "angulo_mediano_grados": angs[angs.size() / 2] if not angs.is_empty() else 0.0,
		"huesos_con_angulo_mayor_a_5": angs.filter(func(x: float) -> bool: return x > 5.0).size()}

## Posiciones (en el espacio del esqueleto) de JOINTS en el instante t del clip sobre un cuerpo.
func _pose(body: String, anim: Animation, bind: Dictionary, t: float) -> Dictionary:
	var sk: Skeleton3D = _sk[body]
	sk.reset_bone_poses()
	PoseSampler.apply(anim, sk, bind, t)
	var out: Dictionary = {}
	for jn in JOINTS:
		out[jn] = PoseSampler.bone_in_skeleton(sk, sk.find_bone(jn)).origin
	return out

func _clips(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("banco,clip,rol,duracion_s,espejo,cuerpo_original,pies_min_json_human_m,pies_min_player_base_m,desvio_max_m,desvio_medio_m,articulacion_peor,contacto_error_json_human_m,contacto_error_player_base_m,salto_pose_inicio_m,salto_pose_fin_m")
	var res: Dictionary = {}
	for bank in BANKS:
		var devs: Array = []
		var feet_j: Array = []
		var cerr: Dictionary = {"json_human": [], "player_base": []}
		var jumps: Array = []
		var n: int = 0
		var idle_pose: Dictionary = _idle_pose(bank)
		for lib_path in BANKS[bank]:
			var lib: AnimationLibrary = load(lib_path)
			for name in lib.get_animation_list():
				var anim: Animation = lib.get_animation(name)
				var meta: Dictionary = anim.get_meta("pack", {}) if anim.has_meta("pack") else {}
				var binds: Dictionary = {}
				for body in BODIES:
					binds[body] = PoseSampler.bind(anim, _sk[body])
				var steps: int = clampi(int(anim.length * SAMPLE_HZ), 1, MAX_SAMPLES)
				var feet_min: Dictionary = {"json_human": INF, "player_base": INF}
				var dmax: float = 0.0
				var dsum: float = 0.0
				var worst: String = ""
				for s in steps + 1:
					var t: float = anim.length * float(s) / float(steps)
					var pj: Dictionary = _pose("json_human", anim, binds["json_human"], t)
					var pp: Dictionary = _pose("player_base", anim, binds["player_base"], t)
					for jn in FEET:
						feet_min["json_human"] = minf(feet_min["json_human"], (pj[jn] as Vector3).y)
						feet_min["player_base"] = minf(feet_min["player_base"], (pp[jn] as Vector3).y)
					var hj: Vector3 = pj["mixamorig_Hips"]
					var hp: Vector3 = pp["mixamorig_Hips"]
					var smax: float = 0.0
					for jn in JOINTS:
						if jn == "mixamorig_Hips":
							continue
						var d: float = ((pj[jn] as Vector3) - Vector3(hj.x, 0.0, hj.z)).distance_to((pp[jn] as Vector3) - Vector3(hp.x, 0.0, hp.z))
						if d > dmax:
							dmax = d
							worst = jn
						smax = maxf(smax, d)
					dsum += smax
				var dmean: float = dsum / float(steps + 1)
				devs.append(dmax)
				feet_j.append(feet_min["json_human"])
				n += 1
				var ce: Dictionary = {"json_human": "", "player_base": ""}
				if meta.has("contact"):
					for body in BODIES:
						var e: float = _contact_error(body, anim, binds[body], meta["contact"])
						ce[body] = "%.3f" % e
						cerr[body].append(e)
				var j0: String = ""
				var j1: String = ""
				if not idle_pose.is_empty():
					var nb: String = NATIVE[bank]
					var a0: float = _pose_jump(idle_pose, _pose(nb, anim, binds[nb], 0.0))
					var a1: float = _pose_jump(idle_pose, _pose(nb, anim, binds[nb], anim.length))
					j0 = "%.3f" % a0
					j1 = "%.3f" % a1
					jumps.append(maxf(a0, a1))
				f.store_line("%s,%s,%s,%.2f,%s,%s,%.3f,%.3f,%.3f,%.3f,%s,%s,%s,%s,%s" % [bank, name, str(meta.get("role", "")), anim.length,
					str(bool(meta.get("mirrored", String(name).ends_with("_mirror")))), NATIVE[bank], feet_min["json_human"], feet_min["player_base"],
					dmax, dmean, worst.trim_prefix("mixamorig_"), ce["json_human"], ce["player_base"], j0, j1])
		devs.sort()
		feet_j.sort()
		res[bank] = {"clips": n, "cuerpo_original": NATIVE[bank], "desvio_max_mediana_m": devs[devs.size() / 2], "desvio_max_p90_m": devs[int(devs.size() * 0.9)],
			"clips_desvio_mayor_10cm": devs.filter(func(x: float) -> bool: return x > 0.10).size(),
			"pies_min_json_human_mediana_m": feet_j[feet_j.size() / 2],
			"clips_pies_hundidos_mas_3cm_en_json_human": feet_j.filter(func(x: float) -> bool: return x < -0.03).size(),
			"clips_pies_flotando_mas_8cm_en_json_human": feet_j.filter(func(x: float) -> bool: return x > 0.08).size(),
			"golpeos_con_contacto": (cerr["json_human"] as Array).size(),
			"contacto_error_mediana_json_human_m": _median(cerr["json_human"]), "contacto_error_mediana_player_base_m": _median(cerr["player_base"]),
			"contacto_error_p90_json_human_m": _quant(cerr["json_human"], 0.9), "contacto_error_p90_player_base_m": _quant(cerr["player_base"], 0.9),
			"transicion_reposo": IDLE[bank] if IDLE[bank] != "" else "sin reposo en el banco",
			"salto_pose_mediana_m": _median(jumps), "salto_pose_p90_m": _quant(jumps, 0.9)}
	f.close()
	return res

## Distancia (metros de juego) entre la punta del pie del clip en el instante de contacto y el contacto de sus metadatos
## (adelante, arriba, derecha respecto del cuerpo; la cadera del clip va en el sitio).
func _contact_error(body: String, anim: Animation, bind: Dictionary, ct: Dictionary) -> float:
	var sk: Skeleton3D = _sk[body]
	sk.reset_bone_poses()
	PoseSampler.apply(anim, sk, bind, float(ct.get("time", 0.0)))
	var toe: String = "mixamorig_RightToeBase" if int(ct.get("foot", 1)) > 0 else "mixamorig_LeftToeBase"
	var p: Vector3 = PoseSampler.bone_in_skeleton(sk, sk.find_bone(toe)).origin * SCALE
	return p.distance_to(ct.get("pos", Vector3.ZERO))

## Pose de reposo del banco (en su cuerpo original) para medir transiciones; {} si el banco no tiene reposo.
func _idle_pose(bank: String) -> Dictionary:
	if String(IDLE[bank]) == "":
		return {}
	for lib_path in BANKS[bank]:
		var lib: AnimationLibrary = load(lib_path)
		if lib.has_animation(StringName(IDLE[bank])):
			var a: Animation = lib.get_animation(StringName(IDLE[bank]))
			var nb: String = NATIVE[bank]
			return _pose(nb, a, PoseSampler.bind(a, _sk[nb]), 0.0)
	return {}

## Mayor distancia (metros de juego) entre dos poses, articulacion por articulacion, relativas a la cadera.
static func _pose_jump(a: Dictionary, b: Dictionary) -> float:
	var ha: Vector3 = a["mixamorig_Hips"]
	var hb: Vector3 = b["mixamorig_Hips"]
	var m: float = 0.0
	for jn in JOINTS:
		if jn == "mixamorig_Hips":
			continue
		m = maxf(m, ((a[jn] as Vector3) - Vector3(ha.x, 0.0, ha.z)).distance_to((b[jn] as Vector3) - Vector3(hb.x, 0.0, hb.z)))
	return m * SCALE

static func _median(xs: Array) -> Variant:
	return _quant(xs, 0.5)

static func _quant(xs: Array, q: float) -> Variant:
	if xs.is_empty():
		return null
	var s: Array = xs.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(q * s.size()))]
