class_name RoyalFlush
extends Minigame
## «Royal Flush» (HABILIDAD). Un tablero de casino con cartas boca abajo; cada carta es una paleta que gira sobre su eje
## horizontal (cuerpo rigido con los demas ejes bloqueados). Un golpe REAL de la pelota en su mitad de arriba o de abajo
## la hace girar; si pasa de 120 grados la traba la deja dada vuelta (como un blanco de pinball) y la carta entra en tu
## mano. Un roce o un golpe al centro (sobre el eje) no la da vuelta: un resorte de detente la vuelve a su lugar.
## Con los tiros del nivel (5) se arma la mano de poker con las PRIMERAS 5 cartas dadas vuelta (si un tiro da vuelta dos,
## entran las dos; pasadas las 5, las demas se dan vuelta pero quedan fuera de la mano). Puntaje: valor de la mano
## (HAND_POINTS) + 5 por carta de la mano.
##
## Niveles en minigames.json ("royal_flush"): distance, cols, rows, deck ("random" | lista de cartas "AH", "10S"...),
## shots, medals. Palos: S picas, H corazones, D diamantes, C treboles.

const SCENE := "res://scenes/minigames/royal_flush.tscn"
const CARD_W := 0.62
const CARD_H := 0.86
const CARD_T := 0.04
const GAP_W := 0.16
const GAP_H := 0.2
## Traba: pasado este angulo la carta queda dada vuelta.
const LATCH := 2.1
## Rigidez del detente (N·m) y de la traba.
const DETENT_K := 0.05
const LATCH_K := 0.25
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS := ["S", "H", "D", "C"]
const SUIT_GLYPH := {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}
const HANDS := ["Carta alta", "Par", "Doble par", "Trío", "Escalera", "Color", "Full", "Póker", "Escalera de color", "Escalera real"]
const HAND_POINTS := [10, 40, 80, 120, 200, 250, 300, 500, 750, 1000]

## Cartas: {body, card ("AH"), revealed, order}
var cards: Array = []
var revealed: Array = []
var shots_max: int = 5
var board_x: float = 14.0
var _board: StaticBody3D

func game_id() -> String:
	return "royal_flush"

func _build_level() -> void:
	sides = 1
	shots_max = int(def.get("shots", 5))
	max_turns = shots_max
	board_x = float(def.get("distance", 14.0))
	var ground := static_box(Vector3(80, 1, 40), Vector3(10, -0.5, 0), Color(0.3, 0.05, 0.08), Vector3.ZERO, 0.45)
	for c in ground.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	_build_stage()
	var cols: int = int(def.get("cols", 5))
	var rows: int = int(def.get("rows", 3))
	var bw: float = float(cols) * (CARD_W + GAP_W) + 0.5
	var bh: float = float(rows) * (CARD_H + GAP_H) + 0.5
	var y0: float = float(def.get("base_y", 0.45))
	# Tablero (fondo de paño verde con marco dorado), detras de las cartas.
	# El paño queda detras del giro de las paletas (media carta + margen): si estuviera mas cerca, la carta chocaria con el
	# a los 28 grados y nunca se daria vuelta.
	var back_x: float = board_x + CARD_H * 0.5 + 0.12
	_board = static_box(Vector3(0.2, bh, bw), Vector3(back_x + 0.1, y0 + bh * 0.5 - 0.25, 0), Color(0.05, 0.35, 0.18), Vector3.ZERO, 0.4)
	for c in _board.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ArcadeLook.mat(Color(0.06, 0.36, 0.2), "paint", 3.0)
	var gold := ArcadeLook.mat(Color(0.95, 0.75, 0.25), "metal")
	# Marco dorado: arriba y abajo en el plano de las cartas (fuera de su giro) y a los costados hasta el paño.
	for s in [[Vector3(0.25, 0.14, bw + 0.28), Vector3(board_x + 0.25, y0 + bh - 0.18, 0)], [Vector3(0.25, 0.14, bw + 0.28), Vector3(board_x + 0.25, y0 - 0.32, 0)],
			[Vector3(back_x - board_x + 0.45, bh + 0.28, 0.14), Vector3((board_x + back_x) * 0.5 + 0.1, y0 + bh * 0.5 - 0.25, bw * 0.5 + 0.07)], [Vector3(back_x - board_x + 0.45, bh + 0.28, 0.14), Vector3((board_x + back_x) * 0.5 + 0.1, y0 + bh * 0.5 - 0.25, -bw * 0.5 - 0.07)]]:
		ArcadeLook.deco(self, "box", s[0], s[1], gold)
	# Bombitas en el marco (brillan; sin luces extra).
	for k in 14:
		var zz: float = -bw * 0.5 + bw * float(k) / 13.0
		ArcadeLook.deco(self, "sphere", Vector3(0.05, 0, 0), Vector3(board_x + 0.1, y0 + bh - 0.18, zz), ArcadeLook.glow(Color(1.0, 0.9, 0.5), 2.5))
		ArcadeLook.deco(self, "sphere", Vector3(0.05, 0, 0), Vector3(board_x + 0.1, y0 - 0.32, zz), ArcadeLook.glow(Color(1.0, 0.9, 0.5), 2.5))
	var deck: Array = _deck(cols * rows)
	var n: int = 0
	for r in rows:
		for c in cols:
			var pos := Vector3(board_x, y0 + CARD_H * 0.5 + float(r) * (CARD_H + GAP_H), (float(c) - float(cols - 1) * 0.5) * (CARD_W + GAP_W))
			_spawn_card(pos, String(deck[n]))
			n += 1

## Mazo del nivel: el fijo de los datos o uno mezclado con la semilla de la partida (sin repetir cartas).
func _deck(n: int) -> Array:
	var given: Variant = def.get("deck", "random")
	if given is Array and (given as Array).size() >= n:
		var d: Array = (given as Array).duplicate()
		# Las cartas dadas se reparten en lugares al azar.
		for i in range(d.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var t: Variant = d[i]
			d[i] = d[j]
			d[j] = t
		return d.slice(0, n)
	var all: Array = []
	for s in SUITS:
		for r in RANKS:
			all.append(r + s)
	for i in range(all.size() - 1, 0, -1):
		var j2: int = rng.randi_range(0, i)
		var t2: Variant = all[i]
		all[i] = all[j2]
		all[j2] = t2
	return all.slice(0, n)

func _spawn_card(pos: Vector3, card: String) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 0.3
	rb.collision_layer = Ball.LAYER_WORLD
	rb.collision_mask = Ball.LAYER_WORLD | Ball.LAYER_BALL
	# Solo gira sobre el eje horizontal del ancho de la carta (Z): la paleta del tablero.
	rb.axis_lock_linear_x = true
	rb.axis_lock_linear_y = true
	rb.axis_lock_linear_z = true
	rb.axis_lock_angular_x = true
	rb.axis_lock_angular_y = true
	rb.angular_damp = 1.5
	rb.can_sleep = false
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	rb.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CARD_T, CARD_H, CARD_W)
	cs.shape = bs
	rb.add_child(cs)
	# Dorso (hacia el jugador): rojo con marco dorado.
	ArcadeLook.part(rb, "box", Vector3(CARD_T, CARD_H, CARD_W), Vector3.ZERO, ArcadeLook.mat(Color(0.65, 0.08, 0.12), "paint"))
	ArcadeLook.part(rb, "box", Vector3(0.004, CARD_H - 0.12, CARD_W - 0.12), Vector3(-CARD_T * 0.5 - 0.002, 0, 0), ArcadeLook.mat(Color(0.78, 0.14, 0.18), "paint"))
	ArcadeLook.part(rb, "box", Vector3(0.004, 0.16, 0.16), Vector3(-CARD_T * 0.5 - 0.004, 0, 0), ArcadeLook.mat(Color(0.95, 0.75, 0.25), "metal"), Vector3(PI * 0.25, 0, 0))
	# Frente (hacia el tablero): blanco, valor y palo.
	ArcadeLook.part(rb, "box", Vector3(0.004, CARD_H - 0.04, CARD_W - 0.04), Vector3(CARD_T * 0.5 + 0.002, 0, 0), ArcadeLook.mat(Color(0.97, 0.96, 0.92), "plastic"))
	var red: bool = card.ends_with("H") or card.ends_with("D")
	var ink: Color = Color(0.85, 0.08, 0.1) if red else Color(0.08, 0.08, 0.1)
	var rank: String = card.substr(0, card.length() - 1)
	for corner in [Vector3(0, CARD_H * 0.32, -CARD_W * 0.28), Vector3(0, -CARD_H * 0.32, CARD_W * 0.28)]:
		var l := Label3D.new()
		l.text = rank
		l.font_size = 96
		l.pixel_size = 0.0022
		l.modulate = ink
		l.outline_size = 0
		l.double_sided = false
		l.rotation_degrees = Vector3(0, 90, 0)
		l.position = Vector3(CARD_T * 0.5 + 0.006, 0, 0) + corner
		rb.add_child(l)
	_suit_mesh(rb, card.substr(card.length() - 1), ink, Vector3(CARD_T * 0.5 + 0.006, 0, 0))
	add_child(rb)
	rb.global_position = pos
	cards.append({"body": rb, "card": card, "revealed": false, "order": -1})

## Palo dibujado con piezas 3D planas sobre el frente (no depende de que la fuente tenga los simbolos).
func _suit_mesh(parent: Node3D, suit: String, ink: Color, at: Vector3) -> void:
	var m := ArcadeLook.mat(ink, "plastic")
	var disc := func(p: Vector3, r: float) -> void:
		ArcadeLook.part(parent, "cyl", Vector3(r, 0.006, r), at + p, m, Vector3(0, 0, PI * 0.5))
	var diamond := func(p: Vector3, s: float) -> void:
		ArcadeLook.part(parent, "box", Vector3(0.006, s, s), at + p, m, Vector3(PI * 0.25, 0, 0))
	match suit:
		"D":
			ArcadeLook.part(parent, "box", Vector3(0.006, 0.16, 0.16), at, m, Vector3(PI * 0.25, 0, 0)).scale = Vector3(1, 1.0, 0.75)
		"H":
			disc.call(Vector3(0, 0.04, -0.055), 0.07)
			disc.call(Vector3(0, 0.04, 0.055), 0.07)
			diamond.call(Vector3(0, -0.02, 0), 0.14)
		"S":
			disc.call(Vector3(0, -0.02, -0.055), 0.07)
			disc.call(Vector3(0, -0.02, 0.055), 0.07)
			diamond.call(Vector3(0, 0.04, 0), 0.14)
			ArcadeLook.part(parent, "box", Vector3(0.006, 0.1, 0.03), at + Vector3(0, -0.1, 0), m)
		_:
			disc.call(Vector3(0, 0.06, 0), 0.055)
			disc.call(Vector3(0, -0.01, -0.06), 0.055)
			disc.call(Vector3(0, -0.01, 0.06), 0.055)
			ArcadeLook.part(parent, "box", Vector3(0.006, 0.12, 0.03), at + Vector3(0, -0.09, 0), m)

func _build_stage() -> void:
	ArcadeLook.light(self, Color(1.0, 0.9, 0.78), 0.9, Color(0.06, 0.04, 0.12), Color(0.3, 0.12, 0.22), 0.7, Vector3(-50, -20, 0))
	ArcadeLook.ground(self, Vector2(160, 120), Vector3(10, 0, 0), Color(0.42, 0.06, 0.1), "paint", 50.0)
	# Pasillo de alfombra con borde dorado hacia el tablero.
	ArcadeLook.deco(self, "box", Vector3(board_x + 2.0, 0.01, 3.2), Vector3(board_x * 0.5, 0.006, 0), ArcadeLook.mat(Color(0.12, 0.1, 0.3), "paint", 6.0))
	for z in [-1.65, 1.65]:
		ArcadeLook.deco(self, "box", Vector3(board_x + 2.0, 0.012, 0.1), Vector3(board_x * 0.5, 0.007, z), ArcadeLook.mat(Color(0.95, 0.75, 0.25), "metal"))
	# Pared del fondo con columnas y cartel; mesas de casino a los costados (decoracion).
	ArcadeLook.deco(self, "box", Vector3(0.6, 9.0, 40.0), Vector3(board_x + 6.0, 4.5, 0), ArcadeLook.mat(Color(0.25, 0.06, 0.1), "paint", 4.0))
	for z in [-8.0, -4.5, 4.5, 8.0]:
		ArcadeLook.deco(self, "cyl", Vector3(0.35, 9.0, 0.35), Vector3(board_x + 5.4, 4.5, z), ArcadeLook.mat(Color(0.9, 0.78, 0.5), "stone"))
	ArcadeLook.billboard(self, "ROYAL FLUSH", Vector3(board_x + 5.5, 4.4, 0), 6.0, 1.1, Color(0.12, 0.02, 0.05), Color(1.0, 0.82, 0.3))
	for z in [-7.0, 7.0]:
		for x in [4.0, 9.0]:
			ArcadeLook.deco(self, "cyl", Vector3(1.0, 0.08, 1.0), Vector3(x, 0.85, z), ArcadeLook.mat(Color(0.06, 0.4, 0.2), "paint"))
			ArcadeLook.deco(self, "cyl", Vector3(1.06, 0.1, 1.06), Vector3(x, 0.8, z), ArcadeLook.mat(Color(0.4, 0.22, 0.1), "wood"))
			ArcadeLook.deco(self, "cyl", Vector3(0.12, 0.8, 0.2), Vector3(x, 0.4, z), ArcadeLook.mat(Color(0.3, 0.2, 0.1), "wood"))
			for k in 3:
				ArcadeLook.deco(self, "cyl", Vector3(0.06, 0.02 * float(k + 2), 0.06), Vector3(x + 0.3 - float(k) * 0.2, 0.92, z + 0.2), ArcadeLook.mat([Color(0.9, 0.1, 0.1), Color(0.1, 0.3, 0.9), Color(0.95, 0.95, 0.95)][k], "plastic"))

# --- Mecanismo ----------------------------------------------------------------------------------------------------------

## Angulo de la paleta (rad, sobre Z): 0 boca abajo, +-PI dada vuelta.
func card_angle(e: Dictionary) -> float:
	return (e["body"] as RigidBody3D).rotation.z

func _level_step(_delta: float) -> void:
	for e in cards:
		var rb: RigidBody3D = e["body"]
		var a: float = card_angle(e)
		if not bool(e["revealed"]) and absf(a) > LATCH:
			# Paso la traba: queda dada vuelta y entra en la mano.
			e["revealed"] = true
			e["order"] = revealed.size()
			revealed.append(e["card"])
			_refresh_score()
		# Detente (estable boca abajo y dada vuelta) o traba (solo dada vuelta).
		var tq: float
		if bool(e["revealed"]):
			tq = -LATCH_K * sin(a - (PI if a > 0.0 else -PI))
		else:
			tq = -DETENT_K * 2.0 * sin(2.0 * a)
		rb.apply_torque(Vector3(0, 0, tq))

func _settling() -> bool:
	for e in cards:
		if (e["body"] as RigidBody3D).angular_velocity.length() > 0.4:
			return true
	return false

func reset_level() -> void:
	for e in cards:
		var rb: RigidBody3D = e["body"]
		rb.rotation = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		e["revealed"] = false
		e["order"] = -1
	revealed.clear()
	super.reset_level()

func _ball_spot(_s: int) -> Vector3:
	return Vector3(0.0, ball.radius if ball != null else 0.11, 0.0)

func _aim_point(_s: int) -> Vector3:
	return Vector3(board_x, 1.4, 0.0)

func _shot_ctx(_s: int) -> Dictionary:
	return GestureShotModel.context(board_x - 0.5, Vector2(9.0, 28.0), false, 4.0, 4.0, ball.radius)

func frame_points() -> Array:
	var out: Array = []
	for e in cards:
		out.append((e["body"] as Node3D).global_position)
	return out

func _flight_check(_delta: float) -> String:
	if _t > 0.8 and not _settling() and (ball.linear_velocity.length() < SLOW_SPEED or ball.global_position.x > board_x + 4.0 or absf(ball.global_position.z) > 12.0):
		return "listo"
	return ""

func _check_winner() -> int:
	return Side.USER if int(shots[0]) >= shots_max else -1

func _on_resolved(s: int, _r: String) -> void:
	var id: StringName = SpReactions.pick(SpReactions.GOAL_SCORER if hand_rank(best_hand()) >= 1 else SpReactions.MISS_SHOOTER, rng, 1.2, 1.0)
	if id != &"" and s < shooters.size():
		shooters[s].actor.play_here(id, 0.3)

# --- Poker --------------------------------------------------------------------------------------------------------------

static func rank_value(card: String) -> int:
	return RANKS.find(card.substr(0, card.length() - 1)) + 2

## Valor de una mano de hasta 5 cartas: indice en HANDS (0 carta alta .. 9 escalera real).
static func hand_rank(hand: Array) -> int:
	if hand.is_empty():
		return -1
	var vals: Array = []
	var suits: Dictionary = {}
	var counts: Dictionary = {}
	for c in hand:
		var v: int = rank_value(String(c))
		vals.append(v)
		counts[v] = int(counts.get(v, 0)) + 1
		suits[String(c).substr(String(c).length() - 1)] = true
	vals.sort()
	var groups: Array = counts.values()
	groups.sort()
	groups.reverse()
	var five: bool = hand.size() == 5
	var flush: bool = five and suits.size() == 1
	var straight := false
	if five and counts.size() == 5:
		straight = int(vals[4]) - int(vals[0]) == 4 or vals == [2, 3, 4, 5, 14]
	if straight and flush:
		return 9 if int(vals[0]) == 10 else 8
	if int(groups[0]) == 4:
		return 7
	if int(groups[0]) == 3 and groups.size() > 1 and int(groups[1]) == 2:
		return 6
	if flush:
		return 5
	if straight:
		return 4
	if int(groups[0]) == 3:
		return 3
	if int(groups[0]) == 2 and groups.size() > 1 and int(groups[1]) == 2:
		return 2
	if int(groups[0]) == 2:
		return 1
	return 0

## La mano: las primeras 5 cartas dadas vuelta.
func best_hand() -> Array:
	return revealed.slice(0, 5)

static func best_of(pool: Array) -> Array:
	if pool.size() <= 5:
		return pool.duplicate()
	var best: Array = []
	var best_r: int = -1
	var best_sum: int = -1
	var n: int = pool.size()
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						var h: Array = [pool[a], pool[b], pool[c], pool[d], pool[e]]
						var r: int = hand_rank(h)
						var sum: int = 0
						for x in h:
							sum += rank_value(String(x))
						if r > best_r or (r == best_r and sum > best_sum):
							best_r = r
							best_sum = sum
							best = h
	return best

func final_score() -> int:
	var r: int = hand_rank(best_hand())
	if r < 0:
		return 0
	return int(HAND_POINTS[r]) + 5 * best_hand().size()

static func pretty(card: String) -> String:
	return card.substr(0, card.length() - 1) + String(SUIT_GLYPH.get(card.substr(card.length() - 1), ""))

func _result_text(_r: String) -> Array:
	var h: Array = best_hand()
	var r: int = hand_rank(h)
	var names: Array = []
	for c in h:
		names.append(pretty(String(c)))
	if r < 0:
		return ["Ninguna carta", Color(1.0, 0.6, 0.4), "Pegale arriba o abajo de una carta para darla vuelta"]
	return [String(HANDS[r]).to_upper(), Color(1.0, 0.85, 0.35) if r >= 1 else Color(1, 1, 1), " ".join(names)]

func _refresh_score() -> void:
	var names: Array = []
	for c in best_hand():
		names.append(pretty(String(c)))
	var r: int = hand_rank(best_hand())
	hud.set_score_text("Mano: %s · %s · tiros %d / %d" % [" ".join(names) if not names.is_empty() else "—", String(HANDS[r]) if r >= 0 else "sin cartas", int(shots[0]), shots_max])
