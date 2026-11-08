extends TestCase
## Modos de tiros libres y penales: reglas de la tanda, eleccion del golpeo por direccion (diestro a su derecha = interior,
## colocada), que el pie del golpeo elegido llegue a la pelota, barrera a 9,15 m que bloquea de verdad, zona valida del tiro
## libre, red de los dos tipos de arco y el flujo completo de un penal y de un tiro libre.

func test_penalty_shootout_rules() -> void:
	var s := PenaltyShootout.new()
	for g in [true, false, true, false, true, false]:
		s.record(PenaltyShootout.USER if s.next_team() == PenaltyShootout.USER else PenaltyShootout.CPU, g)
	# Usuario 3 de 3, CPU 0 de 3: la CPU ya no puede alcanzarlo.
	check(s.goals(0) == 3 and s.goals(1) == 0, "marcador 3-0")
	check(s.finished() and s.winner() == PenaltyShootout.USER, "termina antes de la serie de 5 cuando uno no puede alcanzar al otro")
	s.reset()
	for i in 10:
		s.record(s.next_team(), true)
	check(not s.finished() and s.in_sudden_death(), "5-5: muerte subita")
	s.record(s.next_team(), false)
	check(not s.finished(), "en muerte subita espera el tiro del otro")
	s.record(s.next_team(), true)
	check(s.finished() and s.winner() == PenaltyShootout.CPU, "uno erra y el otro convierte: gana el que convirtio")
	check(s.next_team() == PenaltyShootout.USER, "los turnos alternan empezando por el usuario")

func test_kick_choice_follows_the_direction_of_the_shot() -> void:
	var center := Vector3(1, 0, 0)
	for foot in [1, -1]:
		var app: Vector3 = ShotCatalog.approach_dir(center, foot)
		check(ShotCatalog.signed_deg(center, app) * float(foot) > 10.0, "pie %d: la carrera llega desde el costado de su pie" % foot)
		# Hacia su lado abierto (diestro a la derecha), colocada: interior del pie.
		var open_dir: Vector3 = center.rotated(Vector3.UP, -deg_to_rad(16.0) * float(foot))
		var e: Dictionary = ShotCatalog.choose(foot, ShotCatalog.signed_deg(app, open_dir), ShotCatalog.Kind.PLACED, false, null, 14.0)
		check(not e.is_empty() and int(e["foot"]) == foot, "pie %d: hay golpeo de ese pie" % foot)
		check(ShotCatalog.kind_of(e) == ShotCatalog.Kind.PLACED, "pie %d: al lado abierto coloca con el interior (%s)" % [foot, e.get("id", "-")])
		# Potente y cruzado (dentro del rango de los golpeos potentes del banco): golpeo potente con ese angulo.
		var across: Vector3 = center.rotated(Vector3.UP, deg_to_rad(6.0) * float(foot))
		var rel_wanted: float = ShotCatalog.signed_deg(app, across)
		var e2: Dictionary = ShotCatalog.choose(foot, rel_wanted, ShotCatalog.Kind.POWER, false, null, 27.0)
		note("pie %d: abierto -> %s (rel %.0f), cruzado potente -> %s (rel %.0f, pedido %.0f)" % [foot, e["id"], ShotCatalog.rel_angle(e), e2["id"], ShotCatalog.rel_angle(e2), rel_wanted])
		check(ShotCatalog.kind_of(e2) == ShotCatalog.Kind.POWER, "pie %d: el tiro potente usa un golpeo potente" % foot)
		check(absf(ShotCatalog.rel_angle(e2) - rel_wanted) < 12.0, "pie %d: el golpeo cruzado sale con el angulo pedido" % foot)
		# Muy cruzado (mas alla de los golpeos potentes del banco): alternativa valida de la familia vecina, sin bloquear.
		var far: Vector3 = center.rotated(Vector3.UP, deg_to_rad(18.0) * float(foot))
		var rel_far: float = ShotCatalog.signed_deg(app, far)
		var e3: Dictionary = ShotCatalog.choose(foot, rel_far, ShotCatalog.Kind.POWER, false, null, 27.0)
		note("pie %d: muy cruzado (pedido %.0f) -> %s (%s, rel %.0f)" % [foot, rel_far, e3.get("id", "-"), ShotCatalog.Kind.keys()[ShotCatalog.kind_of(e3)], ShotCatalog.rel_angle(e3)])
		check(not e3.is_empty() and ShotCatalog.kind_of(e3) in [ShotCatalog.Kind.POWER, ShotCatalog.Kind.NORMAL], "pie %d: sin golpeo potente a ese angulo usa uno normal" % foot)
		check(absf(ShotCatalog.rel_angle(e3) - rel_far) < 12.0, "pie %d: y con un angulo cercano" % foot)
	# Todos los tipos tienen golpeos (se usan todos los del banco).
	var per_kind := {}
	for c in ShotCatalog.clips():
		per_kind[ShotCatalog.kind_of(c)] = int(per_kind.get(ShotCatalog.kind_of(c), 0)) + 1
	note("golpeos medidos por familia: %s" % str(per_kind))
	for k in ShotCatalog.Kind.values():
		check(int(per_kind.get(k, 0)) >= 4, "familia %s con golpeos" % ShotCatalog.Kind.keys()[k])

## El golpeo elegido, girado hacia el tiro, pone la punta del pie en la pelota en el instante de contacto (pose medida con
## PoseSampler sobre el humano JSON: no necesita render).
func test_chosen_kicks_put_the_foot_on_the_ball() -> void:
	var body := Node3D.new()
	spawn(body)
	var rig := Node3D.new()
	rig.scale = Vector3.ONE * SpActor.BODY_SCALE
	body.add_child(rig)
	var inst: Node3D = (load(SpActor.BODY) as PackedScene).instantiate()
	rig.add_child(inst)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	await physics_frames(1)
	var ball := Vector3(30.0, 0.1, -4.0)
	var worst: float = 0.0
	var n: int = 0
	for kind in ShotCatalog.Kind.values():
		for foot in [1, -1]:
			for ang in [-20.0, 0.0, 20.0]:
				var dir: Vector3 = Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(ang))
				var e: Dictionary = ShotCatalog.choose(foot, ang, kind, true)
				if e.is_empty():
					continue
				var fr: Array = ShotCatalog.frame_for_shot(e, ball, dir)
				var id := StringName(e["id"])
				var tc: float = float(e["tc"])
				var r: Array = SpActor.body_at(id, tc, fr[0], fr[1])
				body.global_position = r[0]
				body.rotation = Vector3(0.0, SpClips.yaw_of(r[1]), 0.0)
				var anim: Animation = SpClips.anim(id)
				PoseSampler.apply(anim, sk, PoseSampler.bind(anim, sk), tc)
				var toe: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(SpActor.TOE_R if foot > 0 else SpActor.TOE_L))).origin
				var d: float = Vector2(toe.x - ball.x, toe.z - ball.z).length()
				worst = maxf(worst, d)
				n += 1
				check(d < 0.3, "%s (%s, pie %d, %.0f°): el pie llega a la pelota (%.3f m)" % [id, ShotCatalog.Kind.keys()[kind], foot, ang, d])
	note("%d golpeos elegidos, punta del pie a %.3f m como maximo del centro de la pelota (en horizontal)" % [n, worst])
	cleanup()

func test_wall_size_distance_and_free_kick_zone() -> void:
	check(SpWall.count_for(Vector3(32.0, 0, 0), 52.5) == 5, "de frente a 20 m: 5 en la barrera")
	check(SpWall.count_for(Vector3(22.0, 0, -8.0), 52.5) <= 4, "lejos: menos jugadores")
	check(SpWall.count_for(Vector3(42.0, 0, -25.0), 52.5) == 2, "angulo cerrado: 2")
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(5)
	var inside: Vector3 = game.clamp_free_kick_spot(Vector3(45.0, 0, 3.0))
	check(inside.x <= 52.5 - Stadium11.PENALTY_AREA_DEPTH - 0.5, "una pelota dentro del area sale al borde (%.1f)" % inside.x)
	var far: Vector3 = game.clamp_free_kick_spot(Vector3(-20.0, 0, 50.0))
	check(far.x >= 52.5 - SetPieceGame.FK_MAX_X - 0.01 and absf(far.z) <= 34.0, "lejos o fuera de la cancha se acota")
	game.ball_spot = game.clamp_free_kick_spot(Vector3(30.0, 0, -6.0))
	game._setup_free_kick()
	await physics_frames(3)
	var used: int = 0
	for a in game.wall_actors:
		if a.visible:
			used += 1
			var d: float = Vector2(a.global_position.x - game.ball_spot.x, a.global_position.z - game.ball_spot.z).length()
			check_range(d, 9.0, 9.6, "barrera a 9,15 m de la pelota")
	check(used == SpWall.count_for(game.ball_spot, 52.5), "la barrera tiene los jugadores que corresponden (%d)" % used)
	check(game.phase == SetPieceGame.Phase.AIM, "despues de colocar la pelota se apunta")
	cleanup()

## La barrera bloquea de verdad: un tiro raso y fuerte contra ella rebota y no pasa.
func test_the_wall_really_blocks_the_ball() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(5)
	game.ball_spot = game.clamp_free_kick_spot(Vector3(30.0, 0, 0.0))
	game._setup_free_kick()
	await physics_frames(10)
	var pts: Array = []
	for a in game.wall_actors:
		if a.visible:
			pts.append(Vector3(a.global_position.x, 0.0, a.global_position.z))
	# Al cuerpo de cada jugador y a cada hueco entre dos (el peor caso: hombro con hombro no debe pasar).
	var aims: Array = pts.duplicate()
	for k in range(pts.size() - 1):
		aims.append((pts[k] + pts[k + 1]) * 0.5)
	var passed: int = 0
	var hits: int = 0
	for aim in aims:
		game._wall_hit = false
		game.ball.reset_at(game.ball_spot)
		await physics_frames(3)
		var to: Vector3 = aim - game.ball_spot
		to.y = 0.0
		game.ball.kick(to.normalized() * 22.0 + Vector3.UP * 2.0, Vector3.ZERO, null)
		var max_x: float = -INF
		for i in 90:
			await tree.physics_frame
			max_x = maxf(max_x, game.ball.global_position.x)
		if max_x > aim.x + 0.8:
			passed += 1
		if game._wall_hit:
			hits += 1
		note("tiro a (%.2f, %.2f): la pelota llego hasta x = %.2f, sale a %s" % [aim.x, aim.z, max_x, str(game.ball.linear_velocity.snapped(Vector3.ONE * 0.1))])
	check(passed == 0, "la pelota no atraviesa la barrera, ni por los huecos entre jugadores (%d de %d pasaron)" % [passed, aims.size()])
	check(hits == aims.size(), "cada choque contra la barrera se registra (%d de %d)" % [hits, aims.size()])
	cleanup()

func test_both_goal_types_keep_the_ball_in_the_net() -> void:
	for style in [PitchConfig.GoalStyle.BOX, PitchConfig.GoalStyle.SLANTED]:
		var st := Stadium11.new()
		spawn(st)
		var cfg: PitchConfig = PitchConfig.football11(style)
		st.build(cfg)
		var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
		spawn(ball)
		st.set_ball(ball)
		var goals := [0]
		st.goal_scored.connect(func(_g: Goal, _p: Vector3) -> void: goals[0] += 1)
		ball.reset_at(Vector3(40.0, 0.4, 0.0))
		await physics_frames(5)
		ball.kick(Vector3(29.0, 2.6, 1.6), Vector3.ZERO, null)
		var max_x: float = -INF
		var peak: float = 0.0
		var g: Goal = st.get_goal(1)
		var cloth_peak: float = 0.0
		for i in 180:
			await tree.physics_frame
			max_x = maxf(max_x, ball.global_position.x)
			peak = maxf(peak, g.net.bulge)
			if g.cloth != null:
				cloth_peak = maxf(cloth_peak, g.cloth.peak_bulge)
		note("arco %s: gol %d, la pelota llega a %.2f m detras de la linea, red abombada %.2f m, queda en %s" % [SpSettings.GOAL_STYLE_NAMES[style], goals[0], max_x - 52.5, peak, str(ball.global_position.snapped(Vector3.ONE * 0.01))])
		check(goals[0] == 1, "%s: gol" % SpSettings.GOAL_STYLE_NAMES[style])
		check(peak > 0.1, "%s: la red se abomba" % SpSettings.GOAL_STYLE_NAMES[style])
		check(max_x - 52.5 < cfg.goal_depth + Tuning.ball.net_max_bulge + 0.2, "%s: la red la para" % SpSettings.GOAL_STYLE_NAMES[style])
		check(ball.global_position.x > 52.5, "%s: la pelota queda dentro del arco" % SpSettings.GOAL_STYLE_NAMES[style])
		note("arco %s: la tela (nodos e hilos) se mueve hasta %.2f m con el tiro" % [SpSettings.GOAL_STYLE_NAMES[style], cloth_peak])
		check(g.cloth != null, "%s: red de tela de verdad (ClothNet)" % SpSettings.GOAL_STYLE_NAMES[style])
		check(cloth_peak > 0.15, "%s: la tela visible se deforma con la pelota (%.2f m)" % [SpSettings.GOAL_STYLE_NAMES[style], cloth_peak])
		cleanup()

## Flujo completo de un penal del usuario: carrera, contacto en el instante del clip, vuelo, resultado y turno siguiente
## (atajar). El resultado lo decide la fisica.
func test_penalty_turn_flow() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	check(game.phase == SetPieceGame.Phase.AIM and game.user_shooting, "empieza tirando el usuario")
	game.shoot(Vector3(52.5, 0.5, 2.8), 0.7, 0.0)
	check(game.phase == SetPieceGame.Phase.RUNUP, "el tiro arranca la carrera")
	var e: Dictionary = game.last_shot.get("entry", {})
	note("golpeo %s (%s), clase prevista %s" % [e.get("id", "-"), e.get("role", "-"), game.last_shot.get("class", "-")])
	var frames: int = 0
	while game.phase == SetPieceGame.Phase.RUNUP and frames < 400:
		await tree.physics_frame
		frames += 1
	check(game.phase == SetPieceGame.Phase.FLIGHT, "llega al contacto (%d cuadros)" % frames)
	check(game.ball.linear_velocity.length() > 10.0, "la pelota sale golpeada en el contacto")
	while game.phase == SetPieceGame.Phase.FLIGHT and frames < 900:
		await tree.physics_frame
		frames += 1
	check(game.outcome in ["goal", "save", "post", "miss"], "hay resultado (%s)" % game.outcome)
	check(game.shootout.kicks(0) == 1, "se registra el penal")
	await wait_seconds(0.5)
	check(game.phase == SetPieceGame.Phase.KEEPER_PICK and not game.user_shooting, "despues ataja el usuario")
	cleanup()

## Un tiro a la red lateral desde AFUERA hunde la red pero no es gol (la pelota tiene que cruzar la linea entre los palos y
## debajo del travesano). Los dos tipos de arco.
func test_side_netting_from_outside_is_not_a_goal() -> void:
	for style in [PitchConfig.GoalStyle.BOX, PitchConfig.GoalStyle.SLANTED]:
		var st := Stadium11.new()
		spawn(st)
		st.build(PitchConfig.football11(style))
		var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
		spawn(ball)
		st.set_ball(ball)
		var goals := [0]
		st.goal_scored.connect(func(_g: Goal, _p: Vector3) -> void: goals[0] += 1)
		# Desde el costado, por fuera del palo, hacia la red lateral (z = 3,66 + algo, detras de la linea).
		ball.reset_at(Vector3(47.0, 0.5, 8.0))
		await physics_frames(5)
		var target := Vector3(53.3, 0.9, 3.9)
		ball.kick((target - Vector3(47.0, 0.5, 8.0)).normalized() * 24.0 + Vector3.UP * 1.0, Vector3.ZERO, null)
		var min_abs_z: float = INF
		var g: Goal = st.get_goal(1)
		var peak: float = 0.0
		for i in 120:
			await tree.physics_frame
			var lp: Vector3 = g.to_local(ball.global_position)
			if lp.x > 0.1:
				min_abs_z = minf(min_abs_z, absf(lp.z))
			peak = maxf(peak, g.net.bulge)
		note("arco %s, red lateral desde afuera: goles %d, red abombada %.2f m, pelota hasta |z| = %.2f m dentro del plano del arco" % [SpSettings.GOAL_STYLE_NAMES[style], goals[0], peak, min_abs_z])
		check(goals[0] == 0, "%s: la red lateral desde afuera no es gol" % SpSettings.GOAL_STYLE_NAMES[style])
		check(not g.is_goal_now(), "%s: el juego tampoco lo cuenta como gol" % SpSettings.GOAL_STYLE_NAMES[style])
		cleanup()

## Seguro del golpe: si el clip termina sin que se haya disparado el contacto (cuadros perdidos), la pelota sale igual y el
## juego sigue (antes el tiro quedaba trabado esperando).
func test_a_kick_never_gets_stuck() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	game.shoot(Vector3(52.5, 0.6, -2.5), 0.6, 0.0)
	var sh: SpShooter = game.user_shooter
	check(game.phase == SetPieceGame.Phase.RUNUP, "arranca la carrera")
	check(sh.time_to_contact() > 0.2, "se sabe cuanto falta para el contacto (%.2f s)" % sh.time_to_contact())
	# Simula que el clip termino antes de disparar el contacto.
	sh.state = SpShooter.State.KICK
	sh._on_clip_finished(StringName(sh.entry["id"]))
	await physics_frames(2)
	check(sh.kicked, "el golpe sale igual")
	check(game.phase == SetPieceGame.Phase.FLIGHT, "el juego sigue con la pelota en vuelo")
	cleanup()

## El tirador espera AL COSTADO de la pelota (como en los videos): el diestro a la izquierda, el zurdo a la derecha.
func test_shooters_wait_beside_the_ball_on_their_side() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	var saved: int = SpSettings.foot
	for foot in [1, -1]:
		SpSettings.foot = -foot
		game.toggle_foot()
		await physics_frames(2)
		var a: SpActor = game.user_shooter.actor
		var rel: Vector3 = a.global_position - game.ball_spot
		var side: float = rel.dot(SpClips.right_of(Vector3(1, 0, 0)))
		note("pie %s: espera a %.1f m atras y %.1f m al costado (%s)" % ["derecho" if foot > 0 else "izquierdo", -rel.x, side, "izquierda" if side < 0 else "derecha"])
		check(game.user_shooter.foot == foot, "el boton cambia el pie")
		check(side * float(foot) < -1.5, "espera del lado del pie que no patea, al costado (%.1f m)" % side)
		check_range(-rel.x, 1.5, 3.5, "un poco atras de la pelota")
	SpSettings.foot = saved
	SpSettings.save_settings()
	cleanup()

## Superficie del pie medida en cada golpeo y regla de eleccion: colocar = interior, potente = empeine, comba que se
## cierra = interior, comba hacia afuera = exterior (con cada pie).
func test_foot_surface_follows_the_shot() -> void:
	var counts := {}
	for c in ShotCatalog.clips():
		counts[ShotCatalog.surface_of(c)] = int(counts.get(ShotCatalog.surface_of(c), 0)) + 1
	note("golpeos por superficie medida: %s" % str(counts))
	for s in ["interior", "empeine", "exterior"]:
		check(int(counts.get(s, 0)) >= 10, "hay golpeos de %s" % s)
	for foot in [1, -1]:
		check(ShotCatalog.surface_for(ShotCatalog.Kind.PLACED, foot, true, false, 0.0) == "interior", "pie %d: colocar = interior" % foot)
		check(ShotCatalog.surface_for(ShotCatalog.Kind.POWER, foot, false, false, 0.0) == "empeine", "pie %d: potente = empeine" % foot)
		check(ShotCatalog.surface_for(ShotCatalog.Kind.NORMAL, foot, false, true, 30.0 * float(foot)) == "interior", "pie %d: comba que se cierra = interior" % foot)
		check(ShotCatalog.surface_for(ShotCatalog.Kind.NORMAL, foot, false, true, -30.0 * float(foot)) == "exterior", "pie %d: comba hacia afuera = exterior" % foot)
		var e: Dictionary = ShotCatalog.choose(foot, 0.0, ShotCatalog.Kind.PLACED, false, null, 16.0, false, false, "interior")
		check(ShotCatalog.surface_of(e) == "interior" and int(e["foot"]) == foot, "pie %d: colocada al lado abierto con el interior de ese pie (%s)" % [foot, e.get("id", "-")])

## Regresion (el juego se trababa al entrar a un modo en el telefono): iniciar PackLibrary con los jugadores ya conectados a
## las bibliotecas no puede tocar la biblioteca compartida (cada clip agregado hacia reconstruir la cache de cada
## reproductor: 6,5 s en PC con 12 jugadores) y entrar a un modo con el menu cargado tiene que ser rapido.
func test_entering_a_mode_does_not_freeze() -> void:
	var shared: AnimationLibrary = load(PackLibrary.JSON_FIELD_PATH) as AnimationLibrary
	var before: int = shared.get_animation_list().size()
	var actors: Array = []
	for i in 12:
		var a := SpActor.new()
		spawn(a)
		a.build(SpSettings.USER_KIT)
		actors.append(a)
	var t0: int = Time.get_ticks_msec()
	PackLibrary.reload()
	PackLibrary.field()
	var dt: int = Time.get_ticks_msec() - t0
	note("PackLibrary con 12 jugadores conectados: %d ms; biblioteca compartida %d -> %d clips" % [dt, before, shared.get_animation_list().size()])
	check(shared.get_animation_list().size() == before, "la biblioteca compartida no se modifica")
	check(dt < 1500, "iniciar el indice de clips no traba (%d ms)" % dt)
	var menu: Node = (load(MainMenu.SCENE) as PackedScene).instantiate()
	spawn(menu)
	await physics_frames(1)
	for m in [SetPieceGame.Mode.PENALTY, SetPieceGame.Mode.FREE_KICK]:
		SetPieceGame.next_mode = m
		var t1: int = Time.get_ticks_msec()
		var g: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
		spawn(g)
		var dt2: int = Time.get_ticks_msec() - t1
		note("entrar a %s con el menu cargado: %d ms" % ["penales" if m == SetPieceGame.Mode.PENALTY else "tiro libre", dt2])
		check(dt2 < 3000, "entrar al modo no traba (%d ms)" % dt2)
		g.queue_free()
		await physics_frames(1)
	cleanup()

## Contacto del arquero (causa de «la toca pero igual es gol»): antes la normal del choque salia del punto del recorrido
## de la pelota mas cercano a la esfera, que es perpendicular al recorrido, y cualquier toque era un roce (la pelota seguia
## con el 80 % de su velocidad hacia el arco). Ahora se busca el instante real del choque en el movimiento relativo y la
## normal va de la esfera a la pelota en ese instante: de frente la devuelve, de costado la desvia, rozando sigue.
func test_keeper_contact_uses_the_real_impact_normal() -> void:
	var r: float = 0.13 + 0.11
	# De frente: la pelota viene por +X hacia una esfera quieta en el camino.
	var hit: Array = SpKeeper.contact_along(Vector3(-0.5, 1.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(-0.1, 1.0, 0.0), Vector3(-0.1, 1.0, 0.0), r)
	check(not hit.is_empty(), "el choque de frente se detecta dentro del paso")
	var n: Vector3 = ((hit[2] as Vector3) - (hit[1] as Vector3)).normalized()
	check(n.dot(Vector3(-1, 0, 0)) > 0.99, "la normal de frente apunta contra la pelota (%s)" % str(n.snapped(Vector3.ONE * 0.01)))
	var out: Vector3 = SpKeeper.rebound(Vector3(22, 0, 0), Vector3.ZERO, n, 0.28)
	check(out.x < -5.0, "de frente la pelota vuelve hacia la cancha (%.1f m/s)" % out.x)
	# El calculo viejo (punto del recorrido mas cercano al centro) daba una normal perpendicular: ningun rebote.
	var q_old: Vector3 = Geometry3D.get_closest_point_to_segment(Vector3(-0.1, 1.0, 0.0), Vector3(-0.5, 1.0, 0.0), Vector3(0.3, 1.0, 0.02))
	var n_old: Vector3 = (q_old - Vector3(-0.1, 1.0, 0.0)).normalized()
	check(absf(n_old.dot(Vector3(1, 0, 0))) < 0.05, "(el calculo viejo daba una normal perpendicular al tiro)")
	# Roce: pasa a 0,2 m del centro (dentro del radio sumado): se desvia, pero sigue hacia adelante.
	var graze: Array = SpKeeper.contact_along(Vector3(-0.6, 1.0, 0.2), Vector3(0.4, 1.0, 0.2), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 0.0), r)
	check(not graze.is_empty(), "el roce se detecta")
	var ng: Vector3 = ((graze[2] as Vector3) - (graze[1] as Vector3)).normalized()
	var og: Vector3 = SpKeeper.rebound(Vector3(22, 0, 0), Vector3.ZERO, ng, 0.28)
	check(og.x > 5.0 and og.z > 2.0, "rozando sigue hacia adelante y se abre (%s)" % str(og.snapped(Vector3.ONE * 0.1)))
	# Lejos: no hay choque. Una mano que se mueve hacia la pelota la alcanza aunque la pelota sola no llegue.
	check(SpKeeper.contact_along(Vector3(-0.6, 1.0, 0.5), Vector3(0.4, 1.0, 0.5), Vector3.UP, Vector3.UP, r).is_empty(), "lejos no la toca")
	var moving: Array = SpKeeper.contact_along(Vector3(0.0, 1.0, 0.5), Vector3(0.3, 1.0, 0.5), Vector3(0.0, 1.0, 0.0), Vector3(0.3, 1.0, 0.4), r)
	check(not moving.is_empty(), "la mano que se estira hacia la pelota la alcanza")

## El resultado sale enseguida cuando ya no puede ser gol (rebote que se aleja, pelota que se frena antes del arco), pero
## nunca mientras la pelota todavia va hacia el arco.
func test_the_result_is_decided_only_when_a_goal_is_impossible() -> void:
	SetPieceGame.next_mode = SetPieceGame.Mode.PENALTY
	var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
	game.fast = true
	spawn(game)
	await physics_frames(10)
	var cases := [
		[Vector3(game.gx - 2.0, 0.6, 1.0), Vector3(-9.0, 3.0, 4.0), true, "rebote que se aleja del arco"],
		[Vector3(game.gx - 9.0, 0.11, 0.5), Vector3(2.0, 0.0, 0.0), true, "pelota lenta que se frena lejos del arco"],
		[Vector3(game.gx - 11.0, 0.11, 0.0), Vector3(22.0, 2.0, 1.0), false, "tiro que va al arco"],
		# Por el costado (z = 2,6): el arquero espera en el centro y la pelota real rebotaria en sus pies.
		[Vector3(game.gx - 3.0, 0.11, 2.6), Vector3(5.0, 0.0, 0.0), false, "pelota lenta rodando que todavia llega a la linea", true],
		[Vector3(game.gx - 3.0, 0.11, 2.6), Vector3(3.5, 0.0, 0.0), true, "pelota lenta sin giro que desliza y se frena antes de la linea"],
		[Vector3(game.gx - 0.4, 1.5, 0.5), Vector3(0.3, 5.0, 0.0), false, "desviada hacia arriba que cae en la boca del arco"],
		[Vector3(game.gx - 1.0, 2.6, 0.0), Vector3(-1.0, 1.0, 0.0), true, "desviada por encima que cae delante del arco"],
	]
	for c in cases:
		game.ball.reset_at(c[0], Vector3.ZERO)
		await physics_frames(2)
		# Con el giro de rodadura si el caso lo pide (la recolocacion deja el giro en cero: la pelota desliza).
		game.ball.kick(c[1], game.ball.rolling_spin(c[1]) if c.size() > 4 else Vector3.ZERO, null)
		await physics_frames(2)
		game._decide_t = 0.0
		var got: bool = game._goal_impossible(0.0)
		note("%s: %s" % [c[3], "ya no puede ser gol" if got else "todavia puede ser gol"])
		check(got == c[2], "%s: %s" % [c[3], "se decide" if c[2] else "se espera"])
		if absf(c[1].y) < 0.01 and c[1].x > 0.0:
			# Verdad fisica de los casos por el piso: se deja rodar la pelota real y se mira si llega a la linea.
			var max_x: float = -INF
			for i in 240:
				await tree.physics_frame
				max_x = maxf(max_x, game.ball.global_position.x)
			note("   la pelota real llega hasta %.2f m de la linea" % (max_x - game.gx))
			check((max_x >= game.gx - 0.3) == (not c[2]), "%s: la pelota real confirma la decision" % c[3])
	cleanup()
