extends TestCase
## «Botón de caída»: el que cae no atraviesa la plataforma (pedido del usuario: a veces pasaba por el medio de la base).
## Se mide hueso por hueso (cadera, cabeza, pies y manos) durante la caida, en el marco de la plataforma: ningun hueso
## puede quedar por debajo de la tapa fuera del hueco de la trampilla, ni por debajo de una hoja de la trampilla que
## todavia no se abrio lo suficiente.

const BONES := ["mixamorig_Hips", "mixamorig_Head", "mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftHand", "mixamorig_RightHand"]
## Grosor del cuerpo alrededor de cada hueso (m): un hueso a menos de esto del borde ya se ve atravesando.
const BODY_R := 0.12

func _game(level: int) -> BotonCaida:
	var d: Dictionary = MinigameCatalog.level("boton_caida", level)
	d["seed"] = 5
	d["practice"] = true
	Minigame.next_def = d
	var g: BotonCaida = (load(BotonCaida.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	g.start_match()
	await physics_frames(30)
	return g

## Peor violacion de un hueso en el marco de la plataforma s (m que entra en lo solido; 0 = ninguna) y donde.
static func violation(g: BotonCaida, s: int, p_world: Vector3) -> Array:
	var p: Vector3 = g.frames[s].affine_inverse() * p_world
	var h: Vector3 = g._hole_local[s]
	var half: float = BotonCaida.HOLE * 0.5
	# Dentro del espesor de la losa (tapa en y = 0, 1 m de alto).
	if p.y < -0.02 and p.y > -1.0:
		var out_x: float = absf(p.x - h.x) - (half - BODY_R)
		var out_z: float = absf(p.z - h.z) - (half - BODY_R)
		var out: float = maxf(out_x, out_z)
		if out > 0.0:
			return [out, "losa"]
		# Hojas de la trampilla: la mas cercana por z (bisagra en h.z +- half), girada ang hacia abajo.
		var ang: float = clampf(float(g._door_t[s]) / BotonCaida.DOOR_OPEN_T, 0.0, 1.0) * PI * 0.5
		var dz: float = half - absf(p.z - h.z)
		if dz < half * cos(ang):
			var leaf_y: float = -dz * tan(ang) - 0.06
			if p.y < leaf_y - BODY_R:
				return [leaf_y - p.y, "hoja"]
	return [0.0, ""]

func test_falling_player_never_goes_through_the_platform() -> void:
	var report: Array = []
	var worst_all: float = 0.0
	for lv in range(1, MinigameCatalog.levels("boton_caida").size() + 1):
		for s in 2:
			var g: BotonCaida = await _game(lv)
			# El que cae es el que espera (no patea): turno del otro.
			if g.side == s:
				g.side = 1 - s
				g._start_turn()
				await physics_frames(20)
			var a: SpActor = g.shooters[s].actor
			var start: Vector3 = g.frames[s].affine_inverse() * a.global_position
			var hips0: Vector3 = g.frames[s].affine_inverse() * a.bone_world("mixamorig_Hips")
			g.press(s)
			# Solo se mide la caida: el partido no sigue (si no, la IA patearia y el turno nuevo lo volveria a parar).
			g.state = Minigame.State.OVER
			var worst: float = 0.0
			var where: String = ""
			for f in 90:
				await tree.physics_frame
				if not a.visible:
					break
				for b in BONES:
					var v: Array = violation(g, s, a.bone_world(b))
					if float(v[0]) > worst:
						worst = float(v[0])
						where = "%s %s f%d" % [b.trim_prefix("mixamorig_"), v[1], f]
			var h: Vector3 = g._hole_local[s]
			report.append("%d/%d: raiz a (%.2f, %.2f) del centro del hueco, cadera a (%.2f, %.2f); peor %.2f m %s" % [lv, s,
				start.x - h.x, start.z - h.z, hips0.x - h.x, hips0.z - h.z, worst, where])
			worst_all = maxf(worst_all, worst)
			cleanup()
	note("\n         " + "\n         ".join(report))
	check(worst_all < 0.03, "ningun hueso atraviesa la losa ni una hoja cerrada (peor %.2f m)" % worst_all)

## Cada clip permitido para la trampilla, en el nivel 1 y en los dos lados: ninguno saca un hueso del hueco.
func test_every_allowed_fall_clip_fits_the_hole() -> void:
	var clips: Array[StringName] = BotonCaida.fall_clips()
	note("clips de caida permitidos: %s (de %d)" % [str(clips), SpClips.by_role(&"fall", false).size()])
	check(clips.size() >= 2, "hay variedad de caidas que caben")
	var worst_all: float = 0.0
	var lines: Array = []
	for id in clips:
		for s in 2:
			var g: BotonCaida = await _game(1)
			if g.side == s:
				g.side = 1 - s
				g._start_turn()
				await physics_frames(20)
			var a: SpActor = g.shooters[s].actor
			g.press(s)
			g.state = Minigame.State.OVER
			a.play_here(id, 0.1)
			var worst: float = 0.0
			var where: String = ""
			for f in 90:
				await tree.physics_frame
				if not a.visible:
					break
				for b in BONES:
					var v: Array = violation(g, s, a.bone_world(b))
					if float(v[0]) > worst:
						worst = float(v[0])
						where = "%s %s f%d" % [b.trim_prefix("mixamorig_"), v[1], f]
			lines.append("%s/%d %.2f %s" % [id, s, worst, where])
			worst_all = maxf(worst_all, worst)
			cleanup()
	note(", ".join(lines))
	check(worst_all < 0.03, "ninguna caida permitida atraviesa la plataforma (peor %.2f m)" % worst_all)
