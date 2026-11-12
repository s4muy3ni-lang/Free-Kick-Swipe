extends SceneTree
## Reforma, Fase 1: catalogo del banco de animacion JSON original (Mixamo y Mocap se borraron el 2026-11-08 por pedido del
## usuario; docs/reforma/MIXAMO_MOCAP_QUITADOS.md),
## clasificado en las acciones que se comparan para tiros libres y penales (tirador, barrera, arquero). Solo lee las
## bibliotecas: no las modifica ni mezcla bancos. Un clip puede estar en varias categorias; una categoria vacia en un
## banco se muestra como «sin clip en este banco».
##
## Uso: godot --headless --path . --script res://tools/reforma/build_bank_catalog.gd
## Salida: resources/animation/catalogo_bancos.json (lo lee el banco de pruebas, entra en la APK) y
##         docs/reforma/fase1/catalogo_<banco>.csv + docs/reforma/fase1/catalogo_resumen.csv.
##
## Como se clasifica (documentado en docs/reforma/FASE1_INFORME.md):
## - Tirador, barrera, festejos: por rol medido al convertir (JSON) o por el nombre de la toma (Mixamo y Mocap, que no
##   tienen roles de golpeo; ver las listas de abajo).
## - Atajadas: por MEDICION sobre el cuerpo original de cada banco: el punto medio de las dos manos mas la raiz del clip
##   (con los brazos abiertos el punto medio queda en el centro; en una estirada se va hacia un lado). Estirada si llega a
##   >= DIVE_LATERAL_M al costado (izquierda/derecha del arquero por el signo); si no, alta si alguna mano llega a
##   >= HIGH_HAND_M, baja si en el instante del extremo las manos estan a <= LOW_HAND_M, y si no central. Bloqueo y
##   desvio por rol o nombre.
## Ejes (comprobados contra el contacto medido): esqueleto x1.75 = (adelante +X, arriba +Y, derecha +Z), metros de juego;
## la raiz va aparte (meta root_path, adelante y derecha).

const SCALE := 1.75
const OUT := "res://resources/animation/catalogo_bancos.json"
const DOCS := "docs/reforma/fase1"
const DIVE_LATERAL_M := 0.9
const HIGH_HAND_M := 2.0
const LOW_HAND_M := 0.6

const BANKS := {
	"json": {"label": "JSON original", "libs": ["res://assets/animations/json_clips.res", "res://assets/animations/json_keeper.res", "res://assets/animations/json_scenes.res"],
		"body": "res://assets/characters/json/tripo_body.scn"},
}

## [id, grupo, etiqueta]
const CATEGORIES := [
	["st_idle", "Tirador", "Reposo / preparación"],
	["st_run", "Tirador", "Carrera"],
	["st_start", "Tirador", "Arranque y pasos de ajuste"],
	["st_setpiece", "Tirador", "Golpeo de balón parado (tiro libre)"],
	["st_penalty", "Tirador", "Penal (golpeo)"],
	["st_power", "Tirador", "Disparo potente"],
	["st_placed", "Tirador", "Disparo colocado / con efecto"],
	["st_lob", "Tirador", "Vaselina / picado"],
	["st_pass", "Tirador", "Pase de interior"],
	["st_celebrate", "Tirador", "Festejo"],
	["st_dejected", "Tirador", "Lamento"],
	["wa_stand", "Barrera", "Barrera: postura"],
	["wa_jump", "Barrera", "Barrera: salto"],
	["wa_generic_jump", "Barrera", "Salto genérico (no de barrera)"],
	["gk_idle", "Arquero", "Arquero: posición inicial / espera"],
	["gk_side", "Arquero", "Arquero: desplazamiento lateral"],
	["gk_dive_left", "Arquero", "Arquero: estirada a su izquierda"],
	["gk_dive_right", "Arquero", "Arquero: estirada a su derecha"],
	["gk_high", "Arquero", "Arquero: atajada alta"],
	["gk_mid", "Arquero", "Arquero: atajada central / captura"],
	["gk_low", "Arquero", "Arquero: atajada baja"],
	["gk_block", "Arquero", "Arquero: bloqueo"],
	["gk_parry", "Arquero", "Arquero: desvío"],
	["gk_miss", "Arquero", "Arquero: no llega"],
	["gk_getup", "Arquero", "Arquero: levantarse"],
]

## JSON: rol medido -> categorias.
const JSON_ROLES := {
	"idle": ["st_idle"], "idle_ready": ["st_idle"],
	"run": ["st_run"], "sprint": ["st_run"], "jog": ["st_run"], "loco_jog": ["st_run"], "loco_sprint": ["st_run"],
	"start": ["st_start"], "run_change": ["st_start"], "step_stand": ["st_start"], "sidestep": ["st_start"],
	"setpiece_shot": ["st_setpiece"], "setpiece_lob": ["st_setpiece", "st_lob"],
	"kick_shot_hard": ["st_power"], "kick_shot": ["st_placed"], "kick_lob": ["st_lob"],
	"kick_pass": ["st_pass"], "kick_pass_soft": ["st_pass"],
	"celebrate": ["st_celebrate"], "celebrate_scorer": ["st_celebrate"], "celebrate_team": ["st_celebrate"], "dejected": ["st_dejected"],
	"jump": ["wa_generic_jump"],
	"gk_idle": ["gk_idle"], "gk_idle_var": ["gk_idle"], "gk_sidestep": ["gk_side"], "gk_loco": ["gk_side"],
	"gk_miss": ["gk_miss"], "gk_getup": ["gk_getup"],
}
const JSON_SAVE_ROLES := ["gk_dive", "gk_catch", "gk_scoop", "gk_block"]

## Mixamo y Mocap: nombre de la toma (sin _mirror) -> categorias. Las atajadas se clasifican midiendo.
const NAMED := {
	"Soccer_Idle": ["st_idle"], "offensive_idle": ["st_idle"],
	"Running": ["st_run"], "Running_inplace": ["st_run"], "Sprint": ["st_run"], "Sprint_inplace": ["st_run"], "Jogging": ["st_run"],
	"Jogging_inplace": ["st_run"], "Two_Cycle_Sprint": ["st_run"], "Two_Cycle_Sprint_inplace": ["st_run"],
	"Idle_To_Sprint": ["st_start"], "Strafe_3": ["st_start"], "Strafe_3_inplace": ["st_start"],
	"soccer_penalty_kick": ["st_setpiece", "st_penalty"], "strike_foward_jog": ["st_power"], "strike_foward_jog_inplace": ["st_power"],
	"Chip": ["st_lob"], "Soccer_Pass": ["st_pass"],
	"Cheering": ["st_celebrate"], "Cheering_2": ["st_celebrate"], "Excited": ["st_celebrate"], "Fist_Pump": ["st_celebrate"],
	"Fist_Pump_3": ["st_celebrate"], "Standing_Fist_Pump": ["st_celebrate"], "Victory": ["st_celebrate"],
	"Defeat": ["st_dejected"], "Defeat_Idle_2": ["st_dejected"], "Defeated": ["st_dejected"], "Disappointed": ["st_dejected"],
	"Crying": ["st_dejected"], "Loser": ["st_dejected"], "Sad_Idle_3": ["st_dejected"],
	"Jump_2": ["wa_generic_jump"], "Jump_4": ["wa_generic_jump"], "Jumping_Up": ["wa_generic_jump"],
	"goalkeeper_idle": ["gk_idle"], "goalkeeper_idle_2": ["gk_idle"], "goalkeeper_sidestep": ["gk_side"], "goalkeeper_sidestep_2": ["gk_side"],
	"goalkeeper_miss": ["gk_miss"],
	"mc_penalty_kick": ["st_setpiece", "st_penalty"], "mc_penalty_kick_2": ["st_setpiece", "st_penalty"], "mc_power_kick": ["st_power"],
	"mc_side_foot_pass": ["st_pass"], "mc_celebration_1": ["st_celebrate"], "mc_celebration_2": ["st_celebrate"], "mc_celebration_3": ["st_celebrate"],
}
const NAMED_SAVES := ["goalkeeper_diving_save", "goalkeeper_diving_save_2", "goalkeeper_catch", "goalkeeper_catch_2", "goalkeeper_catch_3",
	"goalkeeper_catch_4", "goalkeeper_scoop", "goalkeeper_body_block", "goalkeeper_body_block_2", "goalkeeper_body_block_3",
	"mc_keeper_save_1", "mc_keeper_save_2", "mc_keeper_save_3"]

## JSON: id del juego (y su espejo) -> nombre original de la toma (docs/integration/estado_individual.csv).
var _ucs: Dictionary = {}

func _load_names() -> void:
	var f := FileAccess.open("res://docs/integration/estado_individual.csv", FileAccess.READ)
	if f == null:
		push_error("falta docs/integration/estado_individual.csv (nombres originales del banco JSON)")
		return
	var head: PackedStringArray = f.get_csv_line()
	var i_id: int = head.find("id_juego")
	var i_mirror: int = head.find("id_espejo")
	var i_name: int = head.find("nombre_ucs")
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() <= i_name:
			continue
		for i in [i_id, i_mirror]:
			if row[i] != "":
				_ucs[row[i]] = row[i_name]

func _initialize() -> void:
	_load_names()
	var cat: Dictionary = {"version": 1, "categorias": [], "bancos": {}, "criterios": {"estirada_lateral_m": DIVE_LATERAL_M,
		"atajada_alta_mano_m": HIGH_HAND_M, "atajada_baja_mano_m": LOW_HAND_M, "escala_cuerpo": SCALE}}
	for c in CATEGORIES:
		cat["categorias"].append({"id": c[0], "grupo": c[1], "etiqueta": c[2]})
	DirAccess.make_dir_recursive_absolute(DOCS)
	var summary := FileAccess.open(DOCS + "/catalogo_resumen.csv", FileAccess.WRITE)
	summary.store_line("grupo,categoria," + ",".join(BANKS.keys()))
	var counts: Dictionary = {}
	for bank in BANKS:
		var inst: Node = (load(BANKS[bank]["body"]) as PackedScene).instantiate()
		root.add_child(inst)
		var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
		var clips: Array = []
		var f := FileAccess.open("%s/catalogo_%s.csv" % [DOCS, bank], FileAccess.WRITE)
		f.store_line("banco,clip,toma,espejo,rol,categorias,duracion_s,bucle,raiz_m,contacto_t_s,contacto_pie,contacto_vel_pie_m_s,mano_lateral_m,mano_altura_max_m,salto_cadera_m,pies_min_m")
		for lib_path in BANKS[bank]["libs"]:
			var lib: AnimationLibrary = load(lib_path)
			for name in lib.get_animation_list():
				var e: Dictionary = _entry(bank, String(name), lib.get_animation(name), sk, lib_path)
				if e.is_empty():
					continue
				clips.append(e)
				for c in e["categorias"]:
					var k: String = bank + ":" + c
					counts[k] = int(counts.get(k, 0)) + 1
				var ct: Dictionary = e.get("contacto", {})
				f.store_line("%s,%s,%s,%s,%s,%s,%.2f,%s,%.2f,%s,%s,%s,%.2f,%.2f,%.2f,%.3f" % [bank, e["id"], e["toma"], str(e["espejo"]), e["rol"],
					"|".join(e["categorias"]), e["duracion"], str(e["bucle"]), e["raiz_m"], str(ct.get("t", "")), str(ct.get("pie", "")),
					str(ct.get("vel", "")), e["mano_lateral_m"], e["mano_altura_max_m"], e["salto_cadera_m"], e["pies_min_m"]])
		f.close()
		cat["bancos"][bank] = {"etiqueta": BANKS[bank]["label"], "bibliotecas": BANKS[bank]["libs"], "cuerpo_original": BANKS[bank]["body"], "clips": clips}
		inst.queue_free()
	for c in CATEGORIES:
		var row: Array = [c[1], c[2]]
		for bank in BANKS:
			row.append(str(counts.get(bank + ":" + c[0], 0)))
		summary.store_line(",".join(row))
	summary.close()
	var out := FileAccess.open(OUT, FileAccess.WRITE)
	out.store_string(JSON.stringify(cat, "\t"))
	out.close()
	print("CATALOGO listo: ", OUT)
	quit()

func _base(name: String) -> String:
	return name.trim_suffix("_mirror")

func _entry(bank: String, name: String, anim: Animation, sk: Skeleton3D, lib_path: String) -> Dictionary:
	var m: Dictionary = anim.get_meta("pack", {}) if anim.has_meta("pack") else {}
	var role: String = str(m.get("role", ""))
	var base: String = _base(name)
	var cats: Array = []
	var save: bool = false
	if bank == "json":
		cats = (JSON_ROLES.get(role, []) as Array).duplicate()
		var toma: String = str(_ucs.get(name, m.get("source", "")))
		if role == "setpiece_shot" and toma.contains("SPK"):
			cats.append("st_penalty")
		if role == "wall":
			cats.append("wa_jump" if toma.to_upper().contains("JUMP") else "wa_stand")
		if role == "setpiece_shot" and toma.to_upper().contains("CURL"):
			cats.append("st_placed")
		save = JSON_SAVE_ROLES.has(role)
		if save and _is_parry(toma):
			cats.append("gk_parry")
			save = false
		if role == "gk_block":
			cats.append("gk_block")
			save = false
	else:
		cats = (NAMED.get(base, []) as Array).duplicate()
		save = NAMED_SAVES.has(base)
		if save and base.contains("body_block"):
			cats.append("gk_block")
			save = false
	var meas: Dictionary = _measure(anim, m, sk)
	if save:
		if absf(meas["lateral"]) >= DIVE_LATERAL_M:
			cats.append("gk_dive_right" if meas["lateral"] > 0.0 else "gk_dive_left")
		elif meas["hand_max"] >= HIGH_HAND_M:
			cats.append("gk_high")
		elif role == "gk_scoop" or base == "goalkeeper_scoop" or meas["hand_at_extreme"] <= LOW_HAND_M:
			cats.append("gk_low")
		else:
			cats.append("gk_mid")
	if cats.is_empty():
		return {}
	var e: Dictionary = {"id": name, "biblioteca": lib_path, "toma": str(_ucs.get(name, m.get("source", base))) if bank == "json" else base,
		"espejo": bool(m.get("mirrored", name.ends_with("_mirror"))), "rol": role, "categorias": cats, "duracion": snappedf(anim.length, 0.01),
		"bucle": bool(m.get("loop", anim.loop_mode != Animation.LOOP_NONE)), "raiz_m": snappedf((m.get("root_total", Vector2.ZERO) as Vector2).length(), 0.01),
		"mano_lateral_m": snappedf(meas["lateral"], 0.01), "mano_altura_max_m": snappedf(meas["hand_max"], 0.01),
		"salto_cadera_m": snappedf(meas["hips_rise"], 0.01), "pies_min_m": snappedf(meas["feet_min"], 0.001)}
	if m.has("contact"):
		var ct: Dictionary = m["contact"]
		var p: Vector3 = ct.get("pos", Vector3.ZERO)
		e["contacto"] = {"t": snappedf(float(ct.get("time", 0.0)), 0.001), "pie": "D" if int(ct.get("foot", 1)) > 0 else "I",
			"vel": snappedf(float(ct.get("speed", 0.0)), 0.1), "pos": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]}
	return e

func _is_parry(toma: String) -> bool:
	var u: String = toma.to_upper()
	for w in ["PARRY", "DEFLECT", "PUNCH", "TIP"]:
		if u.contains(w):
			return true
	return false

## Sobre el cuerpo original del banco: extremo lateral del punto medio de las manos (con la raiz del clip), altura maxima
## de las manos, altura de ese punto medio en el instante del extremo lateral, subida de la cadera y altura minima de los pies (metros de juego).
func _measure(anim: Animation, m: Dictionary, sk: Skeleton3D) -> Dictionary:
	var bind: Dictionary = PoseSampler.bind(anim, sk)
	var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
	var hands: Array[int] = [sk.find_bone("mixamorig_LeftHand"), sk.find_bone("mixamorig_RightHand")]
	var feet: Array[int] = [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase"), sk.find_bone("mixamorig_LeftFoot"), sk.find_bone("mixamorig_RightFoot")]
	var hips: int = sk.find_bone("mixamorig_Hips")
	var steps: int = clampi(int(anim.length * 30.0), 1, 300)
	var lateral: float = 0.0
	var hand_at: float = 0.0
	var hand_max: float = 0.0
	var feet_min: float = INF
	var hips0: float = NAN
	var hips_max: float = -INF
	for s in steps + 1:
		var t: float = anim.length * float(s) / float(steps)
		sk.reset_bone_poses()
		PoseSampler.apply(anim, sk, bind, t)
		var root_right: float = _at(rp, t).y if rp.size() >= 2 else 0.0
		var pl: Vector3 = PoseSampler.bone_in_skeleton(sk, hands[0]).origin * SCALE
		var pr: Vector3 = PoseSampler.bone_in_skeleton(sk, hands[1]).origin * SCALE
		var mid: Vector3 = (pl + pr) * 0.5
		var lat: float = mid.z + root_right
		if absf(lat) > absf(lateral):
			lateral = lat
			hand_at = mid.y
		hand_max = maxf(hand_max, maxf(pl.y, pr.y))
		for ft in feet:
			feet_min = minf(feet_min, PoseSampler.bone_in_skeleton(sk, ft).origin.y * SCALE)
		var hy: float = PoseSampler.bone_in_skeleton(sk, hips).origin.y * SCALE
		if is_nan(hips0):
			hips0 = hy
		hips_max = maxf(hips_max, hy)
	return {"lateral": lateral, "hand_at_extreme": hand_at, "hand_max": hand_max, "feet_min": feet_min, "hips_rise": hips_max - hips0}

## Raiz acumulada (adelante, derecha) a 30 Hz, interpolada (misma cuenta que ActionMotion._at, sin depender del juego).
static func _at(path: PackedVector2Array, tt: float) -> Vector2:
	var f: float = clampf(tt * 30.0, 0.0, float(path.size() - 1))
	var i: int = mini(int(f), path.size() - 2)
	return path[i].lerp(path[i + 1], f - float(i))
