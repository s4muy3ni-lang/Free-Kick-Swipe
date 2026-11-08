extends Node
## Tiros libres y penales: mide sobre el humano JSON cada golpeo del banco JSON (punta del pie en el contacto, direccion y
## velocidad del pie, carrera previa) y guarda resources/setpiece/shot_clips.json, que usa ShotCatalog para elegir el
## golpeo segun la direccion del tiro, el pie, la potencia y la altura. No modifica las bibliotecas.
##   godot --headless --path . res://tools/setpiece/build_shot_catalog.tscn
## (Escena y no --script: los scripts del juego usan el autoload Tuning.)

const OUT := "res://resources/setpiece/shot_clips.json"
const ROLES := [&"setpiece_shot", &"setpiece_lob", &"setpiece_pass", &"setpiece_miss", &"kick_shot", &"kick_shot_hard",
	&"kick_lob", &"kick_pass", &"kick_pass_soft"]
const H := 1.0 / 120.0

var body: Node3D
var rig: Node3D
var skeleton: Skeleton3D

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	rig = Node3D.new()
	rig.scale = Vector3.ONE * SpActor.BODY_SCALE
	body.add_child(rig)
	var inst: Node3D = (load(SpActor.BODY) as PackedScene).instantiate()
	rig.add_child(inst)
	skeleton = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	_run.call_deferred()

func _toe(id: StringName, anim: Animation, bind: Dictionary, t: float, bone: int) -> Vector3:
	var r: Array = SpActor.body_at(id, t, Vector3.ZERO, Vector3(1, 0, 0))
	body.global_position = r[0]
	body.rotation = Vector3(0.0, SpClips.yaw_of(r[1]), 0.0)
	PoseSampler.apply(anim, skeleton, bind, t)
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin

func _run() -> void:
	var rows: Array = []
	var seen := {}
	var skipped := {}
	var bl: int = skeleton.find_bone(SpActor.TOE_L)
	var br: int = skeleton.find_bone(SpActor.TOE_R)
	for role in ROLES:
		for id in SpClips.by_role(role):
			if seen.has(id):
				continue
			seen[id] = true
			var m: Dictionary = SpClips.meta(id)
			if not m.has("contact"):
				skipped[id] = "sin contacto"
				continue
			var ct: Dictionary = m["contact"]
			var anim: Animation = SpClips.anim(id)
			var bind: Dictionary = PoseSampler.bind(anim, skeleton)
			var tc: float = float(ct.get("time", 0.0))
			var foot: int = int(ct.get("foot", 1))
			var bone: int = br if foot > 0 else bl
			var p0: Vector3 = _toe(id, anim, bind, tc - H, bone)
			var p: Vector3 = _toe(id, anim, bind, tc, bone)
			var p1: Vector3 = _toe(id, anim, bind, tc + H, bone)
			var v: Vector3 = (p1 - p0) / (2.0 * H)
			var vh := Vector3(v.x, 0.0, v.z)
			if vh.length() < 2.0 or p.y > 0.35:
				skipped[id] = "pie lento o alto (%.1f m/s, %.2f m)" % [vh.length(), p.y]
				continue
			var d: Vector3 = vh.normalized()
			var c: Vector3 = Vector3(p.x, 0.0, p.z) + d * 0.10
			var rc: Vector2 = SpClips.root_at(m, tc)
			var ra: Vector2 = SpClips.root_at(m, maxf(tc - 0.35, 0.0))
			var app: Vector2 = rc - ra
			var face_c: Vector3 = (SpActor.body_at(id, tc, Vector3.ZERO, Vector3(1, 0, 0))[1] as Vector3)
			var approach_yaw: float = atan2(app.y, app.x) if app.length() > 0.12 else atan2(face_c.z, face_c.x)
			# Raiz cada 0.1 s desde el inicio hasta el contacto (para elegir desde donde empezar la carrera).
			var roots: Array = []
			var t: float = 0.0
			while t < tc:
				var rr: Vector2 = SpClips.root_at(m, t)
				roots.append([snappedf(t, 0.001), snappedf(rr.x, 0.001), snappedf(rr.y, 0.001)])
				t += 0.1
			var tags: Array = []
			var tj: Variant = JSON.parse_string(String(m.get("tags", "[]"))) if m.get("tags", null) is String else m.get("tags", [])
			if tj is Array:
				tags = tj
			rows.append({
				"id": String(id), "role": String(SpClips.meta(id).get("role", "")) if not ClipRolesOverlay.ROLE.has(StringName(String(id).trim_suffix("_mirror"))) else String(role),
				"foot": foot, "tc": snappedf(tc, 0.001), "len": snappedf(anim.length, 0.001),
				"cx": snappedf(c.x, 0.001), "cz": snappedf(c.z, 0.001), "toe_y": snappedf(p.y, 0.001),
				"swing": snappedf(rad_to_deg(atan2(d.z, d.x)), 0.1), "elev": snappedf(rad_to_deg(atan2(v.y, vh.length())), 0.1),
				"foot_speed": snappedf(v.length(), 0.01), "approach": snappedf(rad_to_deg(approach_yaw), 0.1),
				"run": snappedf(Vector2(c.x, c.z).length(), 0.01), "clean": bool(ct.get("clean", true)),
				"power": String(m.get("power", "")), "tags": tags, "source": String(m.get("source", "")), "roots": roots,
			})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "clips": rows}, "\t"))
	f.close()
	print("shot_clips: %d golpeos medidos, %d descartados" % [rows.size(), skipped.size()])
	for k in skipped:
		print("  descartado %s: %s" % [k, skipped[k]])
	get_tree().quit()
