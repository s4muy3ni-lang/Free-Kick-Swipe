extends Node
## Velocidad, alcance y toques bajos del pie en clips de pase/tiro/conduccion, en metros de juego (esqueleto de Tripo x 1.75). Requiere render.
## Env: OUT=dir CLIPS=nombre_tripo,ruta/relativa.fbx,...
func _toe_game(sk: Skeleton3D, bone: int) -> Vector3:
	return PoseSampler.bone_in_skeleton(sk, bone).origin * 1.75

func _ready() -> void:
	var out_dir: String = OS.get_environment("OUT")
	var vis := FootballerVisual.new()
	add_child(vis)
	vis.build(FootballerVisual.default_kit(0))
	vis.anim_tree.active = false
	var sk: Skeleton3D = vis.skeleton
	var ysk: Skeleton3D = ((load("res://pack/personaje/ybot_tpose.fbx") as PackedScene).instantiate()).find_children("*", "Skeleton3D", true, false)[0]
	var rt := PackRetarget.new()
	rt.setup(ysk, sk)
	var toes := [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
	var clips: PackedStringArray = OS.get_environment("CLIPS").split(",")
	var res := {}
	for clip in clips:
		var anim: Animation = null
		var bind := {}
		var is_pack: bool = clip.ends_with(".fbx")
		if is_pack:
			var inst: Node = (load("res://pack/animaciones/" + clip) as PackedScene).instantiate()
			var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
			for n in ap.get_animation_list():
				if n != "RESET":
					anim = ap.get_animation(n)
					break
			bind = rt.bind(anim)
		else:
			anim = vis.anim_player.get_animation(clip)
		var steps: int = int(anim.length * 30.0)
		var pos: Array = [[], []]
		for i in steps + 1:
			var t: float = minf(anim.length * float(i) / steps, anim.length)
			if is_pack:
				rt.pose(bind, t, true)
			else:
				PoseSampler.apply(anim, sk, PoseSampler.bind(anim, sk), t)
				# centrar la cadera en horizontal como en el pack (los clips de Tripo ya vienen centrados)
			for f in 2:
				pos[f].append(_toe_game(sk, toes[f]))
		var dt: float = anim.length / steps
		var best := {"speed": 0.0}
		for f in 2:
			for i in range(1, steps + 1):
				var v: Vector3 = (pos[f][i] - pos[f][i - 1]) / dt
				var sp: float = v.length()
				if sp > best["speed"]:
					best = {"speed": sp, "t": i * dt, "foot": f, "fwd": pos[f][i].x, "lat": pos[f][i].z, "h": pos[f][i].y, "vfwd": v.x}
		# golpeo estimado = instante de maxima velocidad de AVANCE del pie (el pico de modulo puede ser el balanceo hacia atras)
		var strike := {"vx": 0.0}
		for f in 2:
			for i in range(1, steps + 1):
				var vx: float = (pos[f][i].x - pos[f][i - 1].x) / dt
				if vx > strike["vx"]:
					strike = {"vx": vx, "t": i * dt, "foot": f, "fwd": pos[f][i].x, "h": pos[f][i].y}
		var max_fwd := -9.0
		var max_t := 0.0
		for f in 2:
			for i in steps + 1:
				if pos[f][i].x > max_fwd:
					max_fwd = pos[f][i].x
					max_t = i * dt
		# toques bajos: maximos locales de avance con el pie casi en el suelo
		var touches: Array = []
		for f in 2:
			for i in range(2, steps - 1):
				var x: float = pos[f][i].x
				if x > pos[f][i - 1].x and x >= pos[f][i + 1].x and pos[f][i].y < 0.14 and x > 0.25:
					touches.append("%.2fs:%s:%.2fm" % [i * dt, "I" if f == 0 else "D", x])
		res[clip] = {"dur": anim.length, "peak_speed": best["speed"], "peak_t": best.get("t", 0.0), "peak_foot": best.get("foot", -1), "peak_fwd": best.get("fwd", 0.0), "peak_h": best.get("h", 0.0), "peak_lat": best.get("lat", 0.0), "peak_vfwd": best.get("vfwd", 0.0), "max_fwd": max_fwd, "max_fwd_t": max_t, "touches": touches, "strike": strike}
		print("%-44s golpeo(vx max)=%5.1f m/s a t=%.2fs pie=%s adelante=%.2f altura=%.2f | dur=%5.2fs pico: v=%5.1f m/s a t=%.2fs pie=%s adelante=%.2f lateral=%.2f altura=%.2f | max adelante=%.2f m a t=%.2fs | toques bajos=%d %s" % [clip.get_file(), strike["vx"], strike.get("t", 0.0), "I" if strike.get("foot", 0) == 0 else "D", strike.get("fwd", 0.0), strike.get("h", 0.0), anim.length, best["speed"], best.get("t", 0.0), "I" if best.get("foot", 0) == 0 else "D", best.get("fwd", 0.0), best.get("lat", 0.0), best.get("h", 0.0), max_fwd, max_t, touches.size(), (" ".join(touches.slice(0, 8)))])
	var f := FileAccess.open(out_dir + "/kickm.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	f.close()
	get_tree().quit()
