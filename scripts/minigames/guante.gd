class_name GuanteDuel
extends Minigame
## «Duelo del guante» (DUELOS, por turnos contra la IA). Dos jugadores frente a frente; cada uno tiene SU maquina,
## montada junto al rival: un gabinete con tres botones que miran a su dueño y un guante en un piston con resorte que
## apunta al pecho del rival. Cada boton apretado por un golpe REAL de la pelota (impacto contra su cara mayor que
## PRESS_SPEED) suma carga a la barra de su dueño:
##  - grande: facil de acertar, carga poca (0,20 por defecto);
##  - mediano: (0,34);
##  - chico: dificil, carga mucho (0,55).
## La carga de cada jugador persiste entre turnos y no pasa de 100 %: lo que sobra se pierde (por eso el chico no siempre
## conviene). Con la carga el guante se retrae como un resorte que se comprime; al 100 % se suelta: el piston es un cuerpo
## con masa empujado por su resorte (x'' = w² (L - x) - c x'), viaja de verdad y su esfera choca con el cuerpo del rival.
## El rival recibe el impulso del choque (masas del guante y del jugador, coeficiente de restitucion) y se desliza hacia
## atras frenado por el rozamiento, con una animacion de impacto (o de caida en el golpe final). Gana el primero que
## conecta "punches" golpes.
## La IA elige boton por valor esperado: probabilidad de acertar con SU error (dispersion a esa distancia) por la carga
## util (la que entra en la barra) y un premio si completa la barra; despues patea con la misma fisica y su error. Nunca
## carga sin que la pelota apriete un boton.
## El usuario puede marcar el boton al que apunta (Grande / Mediano / Chico): solo lo resalta; la carga la da el golpe.
##
## Niveles en minigames.json ("guante"): gap, punches, buttons [{size: "grande"|"mediano"|"chico", r, gain, z, y, move?}].

const SCENE := "res://scenes/minigames/guante.tscn"
const BALL_BACK := 2.2
const PRESS_SPEED := 2.5
const CAP_DEPTH := 0.12
## Gabinete de la maquina, en el marco del rival (x hacia el centro del ring).
const CAB_X := -1.3
const CAB_Z := 3.0
## El piston esta PUNCH_REACH m por delante del rival, a la altura del pecho.
const PUNCH_REACH := 2.5
const PUNCH_Y := 1.25
const GLOVE_R := 0.22
## Retraccion del guante con la barra llena (m) y largo libre del resorte (m, desde el reposo hacia el rival).
const RETRACT := 0.5
const SPRING_L := 2.6
## w² = k/m del resorte (1/s²) y amortiguacion (1/s): unos 9 m/s al llegar al rival (medido en test_guante).
const SPRING_W2 := 11.0
const SPRING_C := 0.6
## Masas (kg) y restitucion del choque guante-cuerpo; rozamiento del deslizamiento del jugador empujado.
const GLOVE_MASS := 20.0
const BODY_MASS := 75.0
const RESTITUTION := 0.3
const FRICTION := 0.55
## Capa propia de los cuerpos de los jugadores (la pelota no la ve: no cambia su vuelo).
const HURT_LAYER := 512
## Error de la IA por dificultad (grados), como en Boton de caida.
const CPU_ERROR := [1.8, 1.3, 1.0, 0.75, 0.55]
const DEFAULT_BUTTONS := [
	{"size": "grande", "r": 0.42, "gain": 0.2, "z": -0.7, "y": 1.0},
	{"size": "mediano", "r": 0.28, "gain": 0.34, "z": 0.08, "y": 1.0},
	{"size": "chico", "r": 0.16, "gain": 0.55, "z": 0.7, "y": 1.0}]

var frames: Array[Transform3D] = []
## Por maquina (indice = dueño): {buttons: [{cap, mesh, r, gain, size, local, move}], glove, area, rod, coil, x, v, mode,
## dir, rest (Vector3 mundo), bar, bar_label, target (rival)}
var machines: Array = []
var charge: Array = [0.0, 0.0]
var hurtboxes: Array = []
## Empujon en curso de cada jugador: velocidad (m/s) y direccion.
var _kb_v: Array = [0.0, 0.0]
var _kb_dir: Array = [Vector3.ZERO, Vector3.ZERO]
var selected: int = 0
var pressed_btn: int = -1
var landed: bool = false
var cpu_error_deg: float = -1.0
var _press_t: float = 0.0
var last_choice: Dictionary = {}

## Duelo cara a cara: los dos jugadores en escena.
func shows_both_players() -> bool:
	return true

## Arma su propia plataforma (o la pelota cambia de lugar): sin la plataforma comun.
func has_player_deck() -> bool:
	return false

func game_id() -> String:
	return "guante"

func _foot(s: int) -> int:
	return SpSettings.foot if s == 0 else 1

func _build_level() -> void:
	sides = 2
	max_turns = int(def.get("max_turns", 40))
	var gap: float = float(def.get("gap", 14.0))
	frames.clear()
	for s in 2:
		frames.append(Transform3D(Basis(Vector3.UP, 0.0 if s == 0 else PI), Vector3((-1.0 if s == 0 else 1.0) * gap * 0.5, 0.0, 0.0)))
	var ground := static_box(Vector3(gap + 24.0, 1, 24), Vector3(0, -0.5, 0), Color(0.12, 0.2, 0.42), Vector3.ZERO, 0.5)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	machines.clear()
	for s in 2:
		machines.append(_build_machine(s))
	for s in 2:
		var hb := AnimatableBody3D.new()
		hb.sync_to_physics = false
		hb.collision_layer = HURT_LAYER
		hb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.28
		cap.height = 1.75
		cs.shape = cap
		hb.add_child(cs)
		add_child(hb)
		hb.global_position = stance_world(s) + Vector3.UP * 0.9
		hurtboxes.append(hb)
	_build_stage(gap)
	ball.body_entered.connect(_on_ball_body)

## Lugar fijo de cada jugador (no depende del boton marcado: el piston se arma apuntando ahi).
func stance_world(s: int) -> Vector3:
	var spot: Vector3 = _ball_spot(s)
	var aim: Vector3 = machine_center(s)
	var a := Vector3(aim.x - spot.x, 0.0, aim.z - spot.z).normalized()
	return Vector3(spot.x, 0.0, spot.z) - a * STANCE.x - SpClips.right_of(a) * STANCE.y * float(_foot(s))

func stance_point(s: int) -> Vector3:
	return stance_world(s)

func _place_shooter(s: int) -> void:
	var sh: SpShooter = shooters[s]
	var spot: Vector3 = _ball_spot(s)
	var aim: Vector3 = machine_center(s)
	sh.actor.visible = true
	sh.actor.freeze_on_finish = false
	sh.actor.ground_y = 0.0
	sh.stance(spot, Vector3(aim.x - spot.x, 0.0, aim.z - spot.z).normalized(), STANCE.x, STANCE.y)
	sh.actor.global_position.y = 0.0
	_kb_v[s] = 0.0

## Centro del gabinete de la maquina del dueño s (esta junto al rival).
func machine_center(s: int) -> Vector3:
	return frames[1 - s] * Vector3(CAB_X + 0.3, 1.0, CAB_Z)

func _ball_spot(s: int) -> Vector3:
	return frames[s] * Vector3(-BALL_BACK, 0.0, 0.0) + Vector3.UP * (ball.radius if ball != null else 0.11)

func _aim_point(s: int) -> Vector3:
	return machine_center(s)

func _shot_ctx(s: int) -> Dictionary:
	var a: Vector3 = _aim_point(s)
	return GestureShotModel.context(a.x, Vector2(11.0, 30.0), false, 6.0, 4.0, ball.radius)

func frame_points() -> Array:
	return [button_center(side, selected), stance_world(1 - side) + Vector3.UP * 1.8]

# --- Maquinas -----------------------------------------------------------------------------------------------------------

func _build_machine(owner: int) -> Dictionary:
	var t: int = 1 - owner
	var fr: Transform3D = frames[t]
	var col: Color = Color(0.2, 0.45, 0.95) if owner == 0 else Color(0.9, 0.25, 0.25)
	var m := {"owner": owner, "target": t, "buttons": [], "x": 0.0, "v": 0.0, "mode": "idle"}
	# Gabinete (cuerpo estatico: la pelota rebota en el) con su panel.
	var cab := static_box(Vector3(0.5, 1.75, 2.4), fr * Vector3(CAB_X + 0.05, 0.875, CAB_Z), Color(0.2, 0.2, 0.24), fr.basis.get_euler(), 0.3)
	for c in cab.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.22, 0.23, 0.27), "metal")
	ArcadeLook.deco(self, "box", Vector3(0.04, 1.6, 2.25), fr * Vector3(CAB_X + 0.31, 0.95, CAB_Z), ArcadeLook.mat(col.darkened(0.25), "paint"), fr.basis.get_euler())
	# Dorso pintado con franjas del color del dueño (lo que ve el otro jugador).
	for k in 3:
		ArcadeLook.deco(self, "box", Vector3(0.03, 0.18, 2.25), fr * Vector3(CAB_X - 0.21, 0.45 + float(k) * 0.45, CAB_Z), ArcadeLook.glow(col, 0.8), fr.basis.get_euler())
	var name_l := Label3D.new()
	name_l.text = "TU MÁQUINA" if owner == 0 else "MÁQUINA CPU"
	name_l.font_size = 64
	name_l.pixel_size = 0.006
	name_l.modulate = Color(1, 1, 1)
	name_l.outline_size = 8
	name_l.double_sided = false
	add_child(name_l)
	name_l.global_transform = fr * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(CAB_X + 0.34, 1.62, CAB_Z))
	# Botones (cara hacia +X del marco del rival = hacia el dueño).
	var bdefs: Array = def.get("buttons", DEFAULT_BUTTONS)
	for i in bdefs.size():
		var bd: Dictionary = bdefs[i]
		var r: float = float(bd.get("r", 0.3))
		var local := Vector3(CAB_X + 0.3 + CAP_DEPTH * 0.5, float(bd.get("y", 1.15)), CAB_Z + float(bd.get("z", 0.0)))
		var cap := AnimatableBody3D.new()
		cap.sync_to_physics = false
		cap.collision_layer = Ball.LAYER_WORLD
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.35
		cap.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = CAP_DEPTH
		cs.shape = cyl
		cap.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = CAP_DEPTH
		cm.radial_segments = 24
		mi.mesh = cm
		var bc: Color = [Color(0.2, 0.85, 0.35), Color(1.0, 0.75, 0.1), Color(0.95, 0.2, 0.15)][mini(i, 2)]
		mi.material_override = ArcadeLook.glow(bc, 0.5)
		cap.add_child(mi)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r
		tm.outer_radius = r + 0.06
		tm.rings = 24
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = ArcadeLook.mat(Color(0.85, 0.86, 0.9), "metal")
		cap.add_child(ring)
		add_child(cap)
		cap.global_transform = fr * Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), local)
		var lab := Label3D.new()
		lab.text = "+%d%%" % int(round(float(bd.get("gain", 0.2)) * 100.0))
		lab.font_size = 48
		lab.pixel_size = 0.005
		lab.outline_size = 8
		lab.double_sided = false
		add_child(lab)
		lab.global_transform = fr * Transform3D(Basis(Vector3.UP, PI * 0.5), local + Vector3(0.05, -r - 0.14, 0))
		var mv: Dictionary = bd.get("move", {})
		var b := {"cap": cap, "mesh": mi, "r": r, "gain": float(bd.get("gain", 0.2)), "size": String(bd.get("size", "")),
			"local": local, "move": mv, "label": lab, "base": cap.global_transform}
		if not mv.is_empty():
			add_mover(cap, fr.basis * BotonCaida._vec(mv.get("axis", [0, 0, 1])), float(mv.get("amp", 0.4)), float(mv.get("speed", 1.2)), float(mv.get("phase", 0.0)))
			b["mover"] = movers.back()
			var lm: Dictionary = add_mover(lab, fr.basis * BotonCaida._vec(mv.get("axis", [0, 0, 1])), float(mv.get("amp", 0.4)), float(mv.get("speed", 1.2)), float(mv.get("phase", 0.0)))
			lm["base"] = lab.global_transform
		(m["buttons"] as Array).append(b)
	# Barra de carga sobre el gabinete (se ve desde el dueño).
	var bar_bg := ArcadeLook.deco(self, "box", Vector3(0.06, 0.22, 2.2), fr * Vector3(CAB_X + 0.3, 1.98, CAB_Z), ArcadeLook.mat(Color(0.08, 0.08, 0.1), "paint"), fr.basis.get_euler())
	bar_bg.name = "BarBg%d" % owner
	var fill := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.08, 0.16, 2.1)
	fill.mesh = fm
	fill.material_override = ArcadeLook.glow(col.lightened(0.2), 1.4)
	add_child(fill)
	m["bar"] = fill
	m["bar_frame"] = fr
	var pct := Label3D.new()
	pct.font_size = 56
	pct.pixel_size = 0.006
	pct.outline_size = 10
	pct.double_sided = false
	add_child(pct)
	pct.global_transform = fr * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(CAB_X + 0.36, 2.3, CAB_Z))
	m["bar_label"] = pct
	# Piston: poste con la caja del resorte frente al rival y el guante.
	var st: Vector3 = frames[t].affine_inverse() * stance_world(t)
	var housing_local := Vector3(st.x + PUNCH_REACH, PUNCH_Y, st.z)
	# La caja del resorte queda detras del guante: con la barra llena el guante llega justo a su frente.
	var box_x: float = housing_local.x + GLOVE_R + RETRACT + 0.38
	var post := static_box(Vector3(0.22, PUNCH_Y - 0.15, 0.22), fr * Vector3(box_x, (PUNCH_Y - 0.15) * 0.5, st.z), Color(0.3, 0.3, 0.34), fr.basis.get_euler(), 0.3)
	for c in post.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.25, 0.26, 0.3), "metal")
	var box := static_box(Vector3(0.7, 0.36, 0.36), fr * Vector3(box_x, PUNCH_Y, st.z), Color(0.3, 0.3, 0.34), fr.basis.get_euler(), 0.3)
	for c in box.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(col.darkened(0.2), "metal")
	var dir: Vector3 = (fr.basis * Vector3(-1, 0, 0)).normalized()
	m["dir"] = dir
	m["rest"] = fr * housing_local
	m["back"] = fr * Vector3(box_x - 0.35, PUNCH_Y, st.z)
	var glove := AnimatableBody3D.new()
	glove.sync_to_physics = false
	glove.collision_layer = Ball.LAYER_WORLD
	var gcs := CollisionShape3D.new()
	var gs := SphereShape3D.new()
	gs.radius = GLOVE_R
	gcs.shape = gs
	glove.add_child(gcs)
	var gm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = GLOVE_R
	sm.height = GLOVE_R * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	gm.mesh = sm
	gm.scale = Vector3(1.15, 1.0, 1.0)
	gm.material_override = ArcadeLook.mat(Color(0.85, 0.08, 0.08), "plastic")
	glove.add_child(gm)
	var thumb := MeshInstance3D.new()
	var tsm := SphereMesh.new()
	tsm.radius = 0.08
	tsm.height = 0.16
	thumb.mesh = tsm
	thumb.material_override = gm.material_override
	thumb.position = Vector3(0.05, 0.05, 0.19)
	glove.add_child(thumb)
	var cuff := MeshInstance3D.new()
	var cfm := CylinderMesh.new()
	cfm.top_radius = 0.15
	cfm.bottom_radius = 0.15
	cfm.height = 0.14
	cuff.mesh = cfm
	cuff.material_override = ArcadeLook.mat(Color(0.95, 0.95, 0.95), "plastic")
	cuff.rotation_degrees = Vector3(0, 0, 90)
	cuff.position = Vector3(0.22, 0, 0)
	glove.add_child(cuff)
	add_child(glove)
	m["glove"] = glove
	# Varilla y resorte (visual, se estiran con el piston).
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.035
	rm.bottom_radius = 0.035
	rm.height = 1.0
	rod.mesh = rm
	rod.material_override = ArcadeLook.mat(Color(0.85, 0.86, 0.9), "metal")
	add_child(rod)
	m["rod"] = rod
	var coils: Array = []
	for k in 7:
		var c := MeshInstance3D.new()
		var ct := TorusMesh.new()
		ct.inner_radius = 0.07
		ct.outer_radius = 0.1
		ct.rings = 12
		ct.ring_segments = 4
		c.mesh = ct
		c.material_override = ArcadeLook.mat(Color(0.95, 0.75, 0.15), "metal")
		add_child(c)
		coils.append(c)
	m["coils"] = coils
	m["basis"] = Basis.looking_at(dir, Vector3.UP)
	_pose_glove(m)
	return m

## Coloca el guante en su posicion x (0 = reposo; negativo = retraido; positivo = hacia el rival) y estira varilla y resorte.
func _pose_glove(m: Dictionary) -> void:
	var dir: Vector3 = m["dir"]
	var rest: Vector3 = m["rest"]
	var gp: Vector3 = rest + dir * float(m["x"])
	var glove: AnimatableBody3D = m["glove"]
	# El guante mira hacia el rival (+X local de la malla = hacia atras, el puño adelante).
	glove.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x) + PI), gp)
	var back: Vector3 = m["back"]
	var span: float = maxf(gp.distance_to(back), 0.05)
	var rod: MeshInstance3D = m["rod"]
	rod.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis(Vector3(1, 0, 0), PI * 0.5), (back + gp) * 0.5)
	rod.scale = Vector3(1, span, 1)
	var coils: Array = m["coils"]
	for k in coils.size():
		var f: float = float(k + 1) / float(coils.size() + 1)
		var c: MeshInstance3D = coils[k]
		c.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis(Vector3(1, 0, 0), PI * 0.5), back.lerp(gp, f))

func button_center(owner: int, i: int) -> Vector3:
	var b: Dictionary = machines[owner]["buttons"][clampi(i, 0, (machines[owner]["buttons"] as Array).size() - 1)]
	return (b["cap"] as Node3D).global_position

func button_normal(owner: int) -> Vector3:
	return (frames[1 - owner].basis * Vector3(1, 0, 0)).normalized()

func button_velocity(owner: int, i: int) -> Vector3:
	var b: Dictionary = machines[owner]["buttons"][i]
	if not b.has("mover"):
		return Vector3.ZERO
	var m: Dictionary = b["mover"]
	return (mover_at(m, level_time + 0.01).origin - mover_at(m, level_time).origin) / 0.01

# --- Escenario ----------------------------------------------------------------------------------------------------------

func _build_stage(gap: float) -> void:
	ArcadeLook.light(self, Color(0.95, 0.9, 1.0), 1.0, Color(0.08, 0.1, 0.25), Color(0.35, 0.3, 0.5), 0.65, Vector3(-58, -25, 0))
	var L: float = gap + 24.0
	# Tarima: lona azul con lineas, borde con luces y una franja central.
	ArcadeLook.ground(self, Vector2(L, 16), Vector3(0, 0, 0), Color(0.16, 0.26, 0.55), "paint", 6.0)
	ArcadeLook.ground(self, Vector2(140, 120), Vector3(0, -0.02, 0), Color(0.08, 0.08, 0.12), "stone", 40.0)
	ArcadeLook.deco(self, "box", Vector3(0.25, 0.01, 16), Vector3(0, 0.006, 0), ArcadeLook.mat(Color(0.95, 0.95, 0.95), "paint"))
	for z in [-8.0, 8.0]:
		ArcadeLook.deco(self, "box", Vector3(L, 0.08, 0.12), Vector3(0, 0.04, z), ArcadeLook.glow(Color(0.3, 0.8, 1.0), 1.8))
	for x in [-L * 0.5, L * 0.5]:
		ArcadeLook.deco(self, "box", Vector3(0.12, 0.08, 16), Vector3(x, 0.04, 0), ArcadeLook.glow(Color(1.0, 0.3, 0.6), 1.8))
	# Tribunas a los costados con publico de colores (bloques), postes de luces y cartel.
	for z in [-14.0, 14.0]:
		for row in 4:
			ArcadeLook.deco(self, "box", Vector3(L, 0.5, 1.2), Vector3(0, 0.25 + float(row) * 0.5, z + signf(z) * float(row) * 1.2), ArcadeLook.mat(Color(0.2, 0.2, 0.26), "stone", 4.0))
			for k in 14:
				var x: float = -L * 0.5 + 1.5 + float(k) * (L - 3.0) / 13.0 + float(row % 2) * 0.6
				var cc: Color = [Color(0.9, 0.2, 0.2), Color(0.2, 0.45, 0.95), Color(0.95, 0.85, 0.2), Color(0.9, 0.9, 0.9)][(k + row) % 4]
				ArcadeLook.deco(self, "box", Vector3(0.35, 0.55, 0.3), Vector3(x, 0.78 + float(row) * 0.5, z + signf(z) * float(row) * 1.2), ArcadeLook.mat(cc, "paint"))
	for x in [-L * 0.5 + 2.0, L * 0.5 - 2.0]:
		for z in [-9.5, 9.5]:
			ArcadeLook.deco(self, "cyl", Vector3(0.08, 7.0, 0.1), Vector3(x, 3.5, z), ArcadeLook.mat(Color(0.3, 0.3, 0.34), "metal"))
			ArcadeLook.deco(self, "box", Vector3(0.6, 0.4, 0.6), Vector3(x, 7.1, z), ArcadeLook.mat(Color(0.2, 0.2, 0.22), "metal"))
			ArcadeLook.deco(self, "sphere", Vector3(0.18, 0, 0), Vector3(x, 6.95, z), ArcadeLook.glow(Color(1.0, 0.95, 0.8), 3.0))
	ArcadeLook.billboard(self, "DUELO DEL GUANTE", Vector3(L * 0.5 + 1.0, 5.0, 0), 9.0, 1.4, Color(0.25, 0.05, 0.12), Color(1.0, 0.85, 0.3))
	var other := ArcadeLook.billboard(self, "DUELO DEL GUANTE", Vector3(-L * 0.5 - 1.0, 5.0, 0), 9.0, 1.4, Color(0.25, 0.05, 0.12), Color(1.0, 0.85, 0.3), 180.0)
	other.name = "SignBack"

# --- Turnos -------------------------------------------------------------------------------------------------------------

func reset_level() -> void:
	charge = [0.0, 0.0]
	for m in machines:
		m["x"] = 0.0
		m["v"] = 0.0
		m["mode"] = "idle"
		_pose_glove(m)
	_kb_v = [0.0, 0.0]
	_refresh_bars()
	super.reset_level()

func _start_turn() -> void:
	pressed_btn = -1
	landed = false
	# Botones apretados vuelven a su lugar (los que se mueven, a su vaiven).
	for m in machines:
		for b in m["buttons"]:
			if b.has("mover"):
				(b["mover"] as Dictionary)["base"] = b["base"]
			else:
				(b["cap"] as Node3D).global_transform = b["base"]
	for s in shooters.size():
		if s != side:
			_place_shooter(s)
	super._start_turn()
	if side == Side.USER:
		_set_user_actions()
	_highlight()

func _on_action(id: StringName) -> void:
	if id == &"select":
		selected = (selected + 1) % (machines[0]["buttons"] as Array).size()
		_highlight()
		_set_user_actions()
		return
	super._on_action(id)

## Botones de la interfaz en el turno del usuario: el boton marcado (rota grande → mediano → chico), camara y reiniciar.
func _set_user_actions() -> void:
	var b: Dictionary = machines[0]["buttons"][selected]
	hud.set_actions([[&"select", "Apunto: %s" % String(b["size"]).capitalize()], [&"camera", "Cámara"], [&"restart", "Reiniciar"]])

## Resalta el boton marcado de la maquina del que patea (solo ayuda a ver a cual va: no cambia la carga).
func _highlight() -> void:
	for owner in machines.size():
		var bs: Array = machines[owner]["buttons"]
		for i in bs.size():
			var lab: Label3D = bs[i]["label"]
			var on: bool = owner == side and i == (selected if side == Side.USER else int(last_choice.get("button", -1)))
			lab.modulate = Color(1.0, 0.95, 0.3) if on else Color(1, 1, 1)
			lab.outline_modulate = Color(0.6, 0.1, 0.0) if on else Color(0, 0, 0)

func _on_ball_body(body: Node) -> void:
	if state != State.FLIGHT or pressed_btn >= 0:
		return
	# Solo cuentan los botones de la maquina del que patea.
	var bs: Array = machines[side]["buttons"]
	for i in bs.size():
		if body == bs[i]["cap"]:
			var n: Vector3 = button_normal(side)
			var rel: Vector3 = prev_velocity() - button_velocity(side, i)
			if -rel.dot(n) >= PRESS_SPEED:
				press(side, i)

## El boton i de la maquina de s quedo apretado por la pelota: se hunde, suma su carga (hasta 100 %) y, llena, suelta el
## guante.
func press(s: int, i: int) -> void:
	pressed_btn = i
	_press_t = 0.0
	var b: Dictionary = machines[s]["buttons"][i]
	var cap: Node3D = b["cap"]
	cap.global_position -= button_normal(s) * CAP_DEPTH * 0.5
	if b.has("mover"):
		(b["mover"] as Dictionary)["base"] = Transform3D((b["mover"]["base"] as Transform3D).basis, (b["mover"]["base"] as Transform3D).origin - button_normal(s) * CAP_DEPTH * 0.5)
	charge[s] = minf(float(charge[s]) + float(b["gain"]), 1.0)
	if float(charge[s]) >= 0.999:
		fire(s)
	_refresh_bars()
	if not fast:
		Sfx.play(&"cheer", 0.4)

## Suelta el resorte del guante de s.
func fire(s: int) -> void:
	var m: Dictionary = machines[s]
	m["mode"] = "fire"
	m["v"] = 0.0

## Paso del piston (resorte con masa) y del empujon del jugador golpeado.
func _level_step(delta: float) -> void:
	_press_t += delta
	for s in 2:
		if s < shooters.size():
			var a: SpActor = shooters[s].actor
			(hurtboxes[s] as Node3D).global_position = Vector3(a.global_position.x, 0.9, a.global_position.z)
			if float(_kb_v[s]) > 0.0:
				var v: float = float(_kb_v[s])
				a.frame_origin += (_kb_dir[s] as Vector3) * v * delta
				a.global_position += (_kb_dir[s] as Vector3) * v * delta
				_kb_v[s] = maxf(v - FRICTION * 9.8 * delta, 0.0)
	for m in machines:
		var x: float = float(m["x"])
		var v: float = float(m["v"])
		match String(m["mode"]):
			"idle":
				# La barra comprime el resorte: el guante va (como resorte amortiguado) a -carga * RETRACT.
				var goal: float = -float(charge[int(m["owner"])]) * RETRACT
				var acc: float = 60.0 * (goal - x) - 14.0 * v
				v += acc * delta
				x += v * delta
			"fire":
				# Resorte liberado: empuja hacia su largo libre; frena solo por su amortiguacion y por el choque.
				var acc2: float = SPRING_W2 * (SPRING_L - x) - SPRING_C * v
				var x0: float = x
				v += acc2 * delta
				x = minf(x + v * delta, SPRING_L)
				# Barrido: el guante recorre hasta 0,2 m por paso; se consulta cada 0,06 m del tramo para no atravesar.
				var n: int = maxi(int(ceil(absf(x - x0) / 0.06)), 1)
				for k in n:
					m["x"] = lerpf(x0, x, float(k + 1) / float(n))
					m["v"] = v
					_pose_glove(m)
					_glove_query(m)
					if String(m["mode"]) != "fire":
						break
				if String(m["mode"]) != "fire":
					continue
				if x >= SPRING_L or (x > 0.0 and v <= 0.0):
					m["mode"] = "return"
			"return":
				var acc3: float = 18.0 * (0.0 - x) - 8.0 * v
				v += acc3 * delta
				x += v * delta
				if absf(x) < 0.02 and absf(v) < 0.05:
					x = 0.0
					v = 0.0
					m["mode"] = "idle"
		m["x"] = x
		m["v"] = v
		_pose_glove(m)
	_refresh_bars()

## Choque del guante: consulta fisica de su esfera contra la capa de los cuerpos de los jugadores (los cuerpos son
## cinematicos y un sensor de Jolt no los ve; la consulta de forma si).
func _glove_query(m: Dictionary) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = GLOVE_R + 0.02
	q.shape = sh
	q.transform = Transform3D(Basis(), (m["glove"] as Node3D).global_position)
	q.collision_mask = HURT_LAYER
	q.collide_with_areas = false
	q.collide_with_bodies = true
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 4):
		_on_glove_contact(hit["collider"], int(m["owner"]))

## El guante toco el cuerpo del rival: choque con masas reales (el guante pierde casi toda su velocidad y el
## jugador sale despedido hacia atras con lo que recibe), animacion de impacto y golpe para el dueño.
func _on_glove_contact(body: Node, owner: int) -> void:
	var m: Dictionary = machines[owner]
	var t: int = int(m["target"])
	if String(m["mode"]) != "fire" or body != hurtboxes[t] or landed:
		return
	var v: float = float(m["v"])
	if v < 1.0:
		return
	landed = true
	var vb: float = (1.0 + RESTITUTION) * GLOVE_MASS * v / (GLOVE_MASS + BODY_MASS)
	var vg: float = v * (GLOVE_MASS - RESTITUTION * BODY_MASS) / (GLOVE_MASS + BODY_MASS)
	m["v"] = vg
	m["mode"] = "return"
	m["hit_speed"] = v
	_kb_v[t] = vb
	_kb_dir[t] = m["dir"]
	points[owner] += 1
	charge[owner] = 0.0
	if t < shooters.size():
		var a: SpActor = shooters[t].actor
		a.stop_moving()
		var final_blow: bool = int(points[owner]) >= int(def.get("punches", 2))
		var pool: Array[StringName] = BotonCaida.fall_clips() if final_blow else _hit_clips()
		if not pool.is_empty():
			a.freeze_on_finish = final_blow
			# Animacion mirando al guante (el golpe llega de frente): el empujon lo lleva hacia atras.
			a.set_facing(-(m["dir"] as Vector3))
			a.play_here(pool[rng.randi() % pool.size()], 0.08)
	if not fast:
		cam.shake(0.5, 0.6)
		Sfx.play(&"cheer", 0.8)

## Reacciones de impacto: tropezones sin desplazamiento propio grande (el empujon lo da la fisica del choque).
static func _hit_clips() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in SpClips.by_role(&"stumble", false):
		if SpClips.root_travel(SpClips.meta(id)) < 0.6:
			out.append(id)
	if out.is_empty():
		out = SpClips.by_role(&"stumble", false)
	return out

func _refresh_bars() -> void:
	for m in machines:
		var o: int = int(m["owner"])
		var c: float = float(charge[o])
		var fr: Transform3D = m["bar_frame"]
		var w: float = maxf(2.1 * c, 0.001)
		var fill: MeshInstance3D = m["bar"]
		fill.global_transform = fr * Transform3D(Basis(), Vector3(CAB_X + 0.33, 1.98, CAB_Z - 1.05 + w * 0.5))
		fill.scale = Vector3(1, 1, w / 2.1)
		(m["bar_label"] as Label3D).text = "%d %%" % int(round(c * 100.0))

func _settling() -> bool:
	for m in machines:
		if String(m["mode"]) != "idle":
			return true
	return float(_kb_v[0]) > 0.0 or float(_kb_v[1]) > 0.0

func _flight_check(_delta: float) -> String:
	if pressed_btn >= 0:
		# Espera el golpe del guante (si se solto) y que el empujado se detenga.
		if _press_t > 0.35 and not _settling():
			return "golpe" if landed else "carga"
		return ""
	var p: Vector3 = ball.global_position
	if absf(p.z) > 30.0 or absf(p.x) > 40.0:
		return "afuera"
	return ""

func _on_resolved(s: int, result: String) -> void:
	var good: bool = result == "golpe" or result == "carga"
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if good else SpReactions.MISS_SHOOTER, rng, 1.3, 1.0)
	if id != &"" and s < shooters.size() and shooters[s].actor.visible:
		shooters[s].actor.play_here(id, 0.3)

func _check_winner() -> int:
	var need: int = int(def.get("punches", 2))
	if int(points[0]) >= need:
		return Side.USER
	if int(points[1]) >= need:
		return Side.CPU
	return -1

func final_score() -> int:
	var s: int = 100 * int(points[0])
	if winner == Side.USER:
		s += 200 + maxi(120 - 10 * int(shots[0]), 0)
	return s

func _result_text(r: String) -> Array:
	var who: String = "Tu guante" if side == Side.USER else "El guante de la CPU"
	match r:
		"golpe":
			return ["¡GUANTAZO!" if side == Side.USER else "¡TE PEGÓ!", Color(0.35, 1.0, 0.45) if side == Side.USER else Color(1.0, 0.4, 0.4),
				"%s conectó · golpes %d - %d" % [who, int(points[0]), int(points[1])]]
		"carga":
			var b: Dictionary = machines[side]["buttons"][pressed_btn]
			return ["+%d %%" % int(round(float(b["gain"]) * 100.0)), Color(1.0, 0.85, 0.35), "Botón %s · carga %d %%" % [String(b["size"]), int(round(float(charge[side]) * 100.0))]]
	return ["Sin carga", Color(1.0, 0.6, 0.4), "La pelota tiene que apretar un botón"]

func _refresh_score() -> void:
	hud.set_score_text("Vos %d %% · golpes %d - %d · CPU %d %%" % [int(round(float(charge[0]) * 100.0)), int(points[0]), int(points[1]), int(round(float(charge[1]) * 100.0))])

# --- IA -----------------------------------------------------------------------------------------------------------------

func _cpu_err() -> float:
	return cpu_error_deg if cpu_error_deg >= 0.0 else float(CPU_ERROR[clampi(SpSettings.level(), 0, CPU_ERROR.size() - 1)])

## Valor esperado de apuntar al boton i de la maquina de s: probabilidad de acertar con su error (dispersion gaussiana a
## esa distancia, dentro del radio util del boton) por la carga que entra en la barra, mas un premio si la completa.
func button_value(s: int, i: int, err_deg: float) -> Dictionary:
	var b: Dictionary = machines[s]["buttons"][i]
	var dist: float = _ball_spot(s).distance_to(button_center(s, i))
	var sigma: float = maxf(dist * tan(deg_to_rad(err_deg)), 0.01)
	var r: float = float(b["r"]) * 0.85
	var p: float = 1.0 - exp(-(r * r) / (2.0 * sigma * sigma))
	if b.has("mover"):
		p *= 0.7
	var room: float = 1.0 - float(charge[s])
	var useful: float = minf(float(b["gain"]), room)
	var v: float = p * useful
	if float(b["gain"]) >= room - 0.001:
		v += p * 0.35
	return {"p": p, "value": v, "useful": useful}

func choose_button(s: int, err_deg: float) -> int:
	var best: int = 0
	var best_v: float = -1.0
	for i in (machines[s]["buttons"] as Array).size():
		var bv: Dictionary = button_value(s, i, err_deg)
		if float(bv["value"]) > best_v:
			best_v = float(bv["value"])
			best = i
	return best

func _cpu_intent() -> Dictionary:
	var err: float = _cpu_err()
	var i: int = choose_button(Side.CPU, err)
	last_choice = {"button": i, "value": button_value(Side.CPU, i, err)}
	_highlight()
	var target: Vector3 = button_center(Side.CPU, i)
	var b: Dictionary = machines[Side.CPU]["buttons"][i]
	var spot: Vector3 = _ball_spot(Side.CPU)
	var speed: float = clampf(spot.distance_to(target) * 0.9 + 5.0, 14.0, 24.0)
	if b.has("mover"):
		# Adelanta el boton que se mueve: donde va a estar cuando llegue la pelota (lo ve moverse).
		var first: Dictionary = cpu_shot(target, speed, 0.0, 0.0)
		var tc: float = ShotSolver.crossing_time(first["trajectory"], target.x)
		var t_fly: float = runup_time + (tc if tc > 0.0 else spot.distance_to(target) / speed)
		target = mover_at(b["mover"], level_time + t_fly).origin
	# Le apunta a la cara del boton (el centro de la pelota cruza el plano a un radio por delante).
	target += button_normal(Side.CPU) * (ball.radius + CAP_DEPTH * 0.5)
	return cpu_shot(target, speed, 0.0, err)
