class_name JsonRetarget
extends RefCounted
## Retarget de las animaciones JSON (solo POSICIONES de 19 articulaciones, sin rotaciones) al esqueleto canonico JsonRig.
##
## Cada hueso toma el MARCO que sale de la geometria de ese instante:
##  - cadera: lateral = cadera izquierda -> derecha; arriba = mitad entre la vertical y la columna (la pelvis se inclina
##    menos que el pecho); pecho: lateral = clavicula izquierda -> derecha, arriba = pelvis -> pecho; columna y cuello:
##    mezcla de los marcos de sus extremos; cabeza: arriba = pecho -> centro de la cabeza.
##  - clavicula: de su origen al hombro de los datos. Brazos y piernas: IK analitica de dos huesos desde el hombro / la
##    cadera hasta la muñeca / el tobillo de los datos con las longitudes del esqueleto; el codo / la rodilla va hacia
##    donde estan en los datos (polo) y, con la extremidad casi estirada (el polo no se distingue), hacia donde lo
##    llevaria la rotacion del padre sin torsion extra. La bisagra (eje del codo / la rodilla) es el segundo vector del
##    marco de brazo y antebrazo / muslo y pierna.
##  - pie: de el tobillo a la punta de los datos; su «arriba» sigue a la pierna en el aire y a la vertical con la punta
##    cerca del suelo (pie plano).
## El marco de REPOSO se calcula con la misma funcion (rest_frames_for), asi cada hueso queda en reposo con su marco y la pose
## de la animacion es el marco absoluto de los datos.

const ARM_POLE_W0 := 0.006
const ARM_POLE_W1 := 0.02
const SPINE_SHARE := [0.34, 0.67]
const NECK_SHARE := 0.45
const PELVIS_TILT_SHARE := 1.0

var pose_kind: int = JsonRig.Pose.A
var rest_pos: Dictionary = {}
var rest_fr: Dictionary = {}
## Posicion de reposo de cada hueso respecto a su padre en el marco de reposo del padre (metros).
var rest_off: Dictionary = {}
## Datos de reposo de los cuatro miembros: {u (direccion raiz->extremo), p (polo), l1, l2}.
var rest_limb: Dictionary = {}

func _init(pose: int = JsonRig.Pose.A) -> void:
	pose_kind = pose
	rest_pos = JsonRig.rest_positions(pose)
	var g: Dictionary = rest_geometry(pose)
	rest_fr = frames_from_geometry(g)
	rest_limb = g["limbs"]
	for i in JsonRig.BONES.size():
		var b: String = JsonRig.BONES[i]
		var par: int = JsonRig.PARENTS[i]
		if par < 0:
			rest_off[b] = rest_pos[b]
		else:
			rest_off[b] = (rest_fr[JsonRig.BONES[par]] as Basis).inverse() * ((rest_pos[b] as Vector3) - (rest_pos[JsonRig.BONES[par]] as Vector3))

static func rest_frames_for(pos: Dictionary) -> Dictionary:
	return frames_from_geometry(_geometry_from_positions(pos, {}))

## Geometria de reposo del esqueleto: vectores que definen los marcos y los datos de los miembros.
static func rest_geometry(pose: int) -> Dictionary:
	var pos: Dictionary = JsonRig.rest_positions(pose)
	var poles := {}
	if pose == JsonRig.Pose.T:
		# El polo del brazo en cruz es el del brazo en pose A girado hasta la horizontal (el codo sigue yendo atras).
		var pa: Dictionary = JsonRig.rest_positions(JsonRig.Pose.A)
		for side in ["Left", "Right"]:
			var s: Vector3 = pa["mixamorig_%sArm" % side]
			var e: Vector3 = pa["mixamorig_%sForeArm" % side]
			var w: Vector3 = pa["mixamorig_%sHand" % side]
			var u_a: Vector3 = (w - s).normalized()
			var p_a: Vector3 = (e - s) - u_a * (e - s).dot(u_a)
			var t_dir := Vector3(0.0, 0.0, 1.0 if side == "Right" else -1.0)
			var rot := Quaternion(((e - s).normalized()), t_dir)
			poles["arm_" + side] = (rot * p_a).normalized()
	return _geometry_from_positions(pos, poles)

static func _pole_of(root: Vector3, mid: Vector3, end: Vector3) -> Vector3:
	var u: Vector3 = (end - root).normalized()
	var p: Vector3 = (mid - root) - u * (mid - root).dot(u)
	return p.normalized() if p.length() > 1e-6 else Vector3.ZERO

static func _geometry_from_positions(pos: Dictionary, poles: Dictionary) -> Dictionary:
	var g := {}
	g["pelvis_lat"] = (pos["mixamorig_RightUpLeg"] as Vector3) - (pos["mixamorig_LeftUpLeg"] as Vector3)
	g["spine_dir"] = (pos["mixamorig_Spine2"] as Vector3) - (pos["mixamorig_Hips"] as Vector3)
	g["chest_lat"] = (pos["mixamorig_RightShoulder"] as Vector3) - (pos["mixamorig_LeftShoulder"] as Vector3)
	g["head_dir"] = JsonRig.head_point() - (pos["mixamorig_Spine2"] as Vector3)
	var limbs := {}
	for side in ["Left", "Right"]:
		var sh: Vector3 = pos["mixamorig_%sShoulder" % side]
		var arm: Vector3 = pos["mixamorig_%sArm" % side]
		var fore: Vector3 = pos["mixamorig_%sForeArm" % side]
		var hand: Vector3 = pos["mixamorig_%sHand" % side]
		var up_leg: Vector3 = pos["mixamorig_%sUpLeg" % side]
		var leg: Vector3 = pos["mixamorig_%sLeg" % side]
		var foot: Vector3 = pos["mixamorig_%sFoot" % side]
		var toe: Vector3 = pos["mixamorig_%sToeBase" % side]
		g["clav_dir_" + side] = arm - sh
		var arm_pole: Vector3 = poles.get("arm_" + side, _pole_of(arm, fore, hand))
		limbs["arm_" + side] = {"u": (hand - arm).normalized(), "p": arm_pole, "l1": (fore - arm).length(), "l2": (hand - fore).length()}
		var leg_pole: Vector3 = _pole_of(up_leg, leg, foot)
		limbs["leg_" + side] = {"u": (foot - up_leg).normalized(), "p": leg_pole, "l1": (leg - up_leg).length(), "l2": (foot - leg).length()}
		g["arm1_dir_" + side] = fore - arm
		g["arm2_dir_" + side] = hand - fore
		g["arm_h_" + side] = (limbs["arm_" + side]["u"] as Vector3).cross(arm_pole).normalized()
		g["leg1_dir_" + side] = leg - up_leg
		g["leg2_dir_" + side] = foot - leg
		g["leg_h_" + side] = (limbs["leg_" + side]["u"] as Vector3).cross(leg_pole).normalized()
		g["foot_dir_" + side] = toe - foot
		g["foot_up_" + side] = Vector3.UP
	g["limbs"] = limbs
	return g

## Marcos de los 23 huesos a partir de los vectores de la geometria (rest_geometry o la de un instante de la animacion).
static func frames_from_geometry(g: Dictionary) -> Dictionary:
	var f := {}
	f["Root"] = Basis.IDENTITY
	var spine: Vector3 = (g["spine_dir"] as Vector3).normalized()
	var up_p: Vector3 = Vector3.UP.lerp(spine, PELVIS_TILT_SHARE).normalized()
	var fp: Basis = JsonRig.frame_lu(g["pelvis_lat"], up_p, true)
	var fc: Basis = JsonRig.frame_lu(g["chest_lat"], spine, true)
	var fh: Basis = JsonRig.frame_lu(g["chest_lat"], g["head_dir"], false)
	f["mixamorig_Hips"] = fp
	f["mixamorig_Spine"] = JsonRig.blend(fp, fc, SPINE_SHARE[0])
	f["mixamorig_Spine1"] = JsonRig.blend(fp, fc, SPINE_SHARE[1])
	f["mixamorig_Spine2"] = fc
	f["mixamorig_Neck"] = JsonRig.blend(fc, fh, NECK_SHARE)
	f["mixamorig_Head"] = fh
	var chest_up: Vector3 = fc.y
	for side in ["Left", "Right"]:
		var fcl: Basis = JsonRig.frame_ds(g["clav_dir_" + side], chest_up)
		f["mixamorig_%sShoulder" % side] = fcl
		var fa: Basis = JsonRig.frame_ds(g["arm1_dir_" + side], g["arm_h_" + side])
		var ff: Basis = JsonRig.frame_ds(g["arm2_dir_" + side], g["arm_h_" + side])
		f["mixamorig_%sArm" % side] = fa
		f["mixamorig_%sForeArm" % side] = ff
		f["mixamorig_%sHand" % side] = ff
		var ft: Basis = JsonRig.frame_ds(g["leg1_dir_" + side], g["leg_h_" + side])
		var fs: Basis = JsonRig.frame_ds(g["leg2_dir_" + side], g["leg_h_" + side])
		f["mixamorig_%sUpLeg" % side] = ft
		f["mixamorig_%sLeg" % side] = fs
		var foot_up: Vector3 = g["foot_up_" + side]
		var ffoot: Basis = JsonRig.frame_ds(g["foot_dir_" + side], foot_up)
		f["mixamorig_%sFoot" % side] = ffoot
		f["mixamorig_%sToeBase" % side] = ffoot
	return f

# --- Un instante de la animacion -----------------------------------------------------------------------------------------

## Resuelve un instante. j: articulaciones de los datos EN EL ESPACIO DEL MODELO (metros): pelvis, chest, head, l_/r_ de
## clavicle, shoulder, elbow, wrist, hip, knee, ankle, toe. Devuelve {"frames": {hueso: Basis}, "hips": Vector3 (m),
## "pos": {hueso: Vector3} posiciones del esqueleto resultante (m), "reach_err": distancia maxima al objetivo (m)}.
func solve(j: Dictionary) -> Dictionary:
	var g := {}
	var pelvis: Vector3 = j["pelvis"]
	var spine: Vector3 = (j["chest"] as Vector3) - pelvis
	var lat_p: Vector3 = (j["r_hip"] as Vector3) - (j["l_hip"] as Vector3)
	var lat_c: Vector3 = (j["r_clavicle"] as Vector3) - (j["l_clavicle"] as Vector3)
	g["pelvis_lat"] = lat_p
	g["spine_dir"] = spine
	g["chest_lat"] = lat_c
	g["head_dir"] = (j["head"] as Vector3) - (j["chest"] as Vector3)
	var up_p: Vector3 = Vector3.UP.lerp(spine.normalized(), PELVIS_TILT_SHARE).normalized()
	var fp: Basis = JsonRig.frame_lu(lat_p, up_p, true)
	var fc: Basis = JsonRig.frame_lu(lat_c, spine, true)
	var pos := {}
	pos["Root"] = Vector3.ZERO
	pos["mixamorig_Hips"] = pelvis
	var fr_early := {"mixamorig_Hips": fp, "mixamorig_Spine2": fc}
	var fh: Basis = JsonRig.frame_lu(lat_c, g["head_dir"], false)
	fr_early["mixamorig_Spine"] = JsonRig.blend(fp, fc, SPINE_SHARE[0])
	fr_early["mixamorig_Spine1"] = JsonRig.blend(fp, fc, SPINE_SHARE[1])
	fr_early["mixamorig_Neck"] = JsonRig.blend(fc, fh, NECK_SHARE)
	fr_early["mixamorig_Head"] = fh
	# Posiciones de la columna por cinematica directa.
	for b in ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head"]:
		var par: String = JsonRig.BONES[JsonRig.PARENTS[JsonRig.BONES.find(b)]]
		pos[b] = (pos[par] as Vector3) + (fr_early[par] as Basis) * (rest_off[b] as Vector3)
	var reach_err := 0.0
	for side in ["Left", "Right"]:
		var s: String = "l_" if side == "Left" else "r_"
		var cl_b := "mixamorig_%sShoulder" % side
		pos[cl_b] = (pos["mixamorig_Spine2"] as Vector3) + fc * (rest_off[cl_b] as Vector3)
		var clav_dir: Vector3 = (j[s + "shoulder"] as Vector3) - (pos[cl_b] as Vector3)
		if clav_dir.length_squared() < 1e-8:
			clav_dir = (rest_fr[cl_b] as Basis).x
		var fcl: Basis = JsonRig.frame_ds(clav_dir, fc.y)
		g["clav_dir_" + side] = clav_dir
		# Hombro (origen del hueso del brazo) por cinematica directa desde la clavicula.
		var arm_b := "mixamorig_%sArm" % side
		pos[arm_b] = (pos[cl_b] as Vector3) + fcl * (rest_off[arm_b] as Vector3)
		var arm: Dictionary = _limb(pos[arm_b], j[s + "wrist"], j[s + "elbow"], rest_limb["arm_" + side], fcl, rest_fr[cl_b])
		g["arm1_dir_" + side] = (arm["mid"] as Vector3) - (pos[arm_b] as Vector3)
		g["arm2_dir_" + side] = (arm["end"] as Vector3) - (arm["mid"] as Vector3)
		g["arm_h_" + side] = arm["h"]
		pos["mixamorig_%sForeArm" % side] = arm["mid"]
		pos["mixamorig_%sHand" % side] = arm["end"]
		reach_err = maxf(reach_err, (arm["end"] as Vector3).distance_to(j[s + "wrist"]))
		# Pierna.
		var leg_b := "mixamorig_%sUpLeg" % side
		pos[leg_b] = pelvis + fp * (rest_off[leg_b] as Vector3)
		var leg: Dictionary = _limb(pos[leg_b], j[s + "ankle"], j[s + "knee"], rest_limb["leg_" + side], fp, rest_fr["mixamorig_Hips"])
		g["leg1_dir_" + side] = (leg["mid"] as Vector3) - (pos[leg_b] as Vector3)
		g["leg2_dir_" + side] = (leg["end"] as Vector3) - (leg["mid"] as Vector3)
		g["leg_h_" + side] = leg["h"]
		pos["mixamorig_%sLeg" % side] = leg["mid"]
		pos["mixamorig_%sFoot" % side] = leg["end"]
		reach_err = maxf(reach_err, (leg["end"] as Vector3).distance_to(j[s + "ankle"]))
		# Pie: de el tobillo logrado a la punta de los datos; el «arriba» sigue a la pierna en el aire y a la vertical en el suelo.
		var foot_dir: Vector3 = (j[s + "toe"] as Vector3) - (leg["end"] as Vector3)
		g["foot_dir_" + side] = foot_dir
		var shin_frame: Basis = JsonRig.frame_ds(g["leg2_dir_" + side], leg["h"])
		var shin_delta: Basis = shin_frame * (rest_fr["mixamorig_%sLeg" % side] as Basis).inverse()
		var up_leg: Vector3 = shin_delta * Vector3.UP
		var w_ground: float = 1.0 - smoothstep(0.02, 0.15, (j[s + "toe"] as Vector3).y)
		g["foot_up_" + side] = up_leg.lerp(Vector3.UP, w_ground).normalized()
		pos["mixamorig_%sToeBase" % side] = (j[s + "toe"] as Vector3)
	# Los marcos finales con los mismos vectores de la geometria (misma funcion que el reposo).
	var fr: Dictionary = frames_from_geometry(_fill_limbs(g))
	return {"frames": fr, "hips": pelvis, "pos": pos, "reach_err": reach_err}

func _fill_limbs(g: Dictionary) -> Dictionary:
	g["limbs"] = rest_limb
	return g

## IK de dos huesos. root, target: puntos; mid_data: codo / rodilla de los datos (solo su lado); lim: datos de reposo del
## miembro; parent_f / parent_f_rest: marco actual y de reposo del hueso padre (para el polo con el miembro estirado).
func _limb(root: Vector3, target: Vector3, mid_data: Vector3, lim: Dictionary, parent_f: Basis, parent_f_rest: Basis) -> Dictionary:
	var l1: float = lim["l1"]
	var l2: float = lim["l2"]
	var to_t: Vector3 = target - root
	var dist: float = to_t.length()
	var q: Basis = parent_f * parent_f_rest.inverse()
	var u: Vector3 = to_t / dist if dist > 1e-5 else (q * (lim["u"] as Vector3)).normalized()
	var d: float = clampf(dist, absf(l1 - l2) + 0.002, l1 + l2 - 0.0015)
	# Polo de los datos.
	var pm: Vector3 = mid_data - root
	var p_data: Vector3 = pm - u * pm.dot(u)
	var pdl: float = p_data.length()
	# Polo de respaldo: el de reposo llevado por la rotacion del padre y por el giro minimo del miembro (sin torsion extra).
	var u0: Vector3 = (q * (lim["u"] as Vector3)).normalized()
	var p0: Vector3 = q * (lim["p"] as Vector3)
	var swing := Quaternion(u0, u)
	var p_fb: Vector3 = swing * p0
	p_fb = (p_fb - u * p_fb.dot(u)).normalized()
	var w: float = smoothstep(ARM_POLE_W0, ARM_POLE_W1, pdl)
	var p: Vector3 = p_fb.lerp(p_data / pdl, w) if pdl > 1e-6 else p_fb
	p = (p - u * p.dot(u))
	p = p.normalized() if p.length_squared() > 1e-10 else p_fb
	var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var hl: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	return {"mid": root + u * a + p * hl, "end": root + u * d, "h": u.cross(p).normalized(), "u": u, "p": p}

# --- Salida --------------------------------------------------------------------------------------------------------------

## Rotaciones locales (Quaternion por hueso) de los marcos globales: q_local = marco(padre)^-1 * marco(hueso).
static func local_rotations(frames: Dictionary) -> Dictionary:
	var out := {}
	for i in JsonRig.BONES.size():
		var b: String = JsonRig.BONES[i]
		var par: int = JsonRig.PARENTS[i]
		var m: Basis = frames[b]
		if par >= 0:
			m = (frames[JsonRig.BONES[par]] as Basis).inverse() * m
		out[b] = m.get_rotation_quaternion()
	return out

## Cinematica directa de un conjunto de marcos: posiciones (m) de todos los huesos, con la cadera en `hips`.
func forward(frames: Dictionary, hips: Vector3) -> Dictionary:
	var pos := {}
	for i in JsonRig.BONES.size():
		var b: String = JsonRig.BONES[i]
		var par: int = JsonRig.PARENTS[i]
		if par < 0:
			pos[b] = Vector3.ZERO
		elif b == "mixamorig_Hips":
			pos[b] = hips
		else:
			pos[b] = (pos[JsonRig.BONES[par]] as Vector3) + (frames[JsonRig.BONES[par]] as Basis) * (rest_off[b] as Vector3)
	return pos
