class_name MatchContext
extends RefCounted
## Vista compartida del partido para controladores, asistencias e IA.
## Contiene referencias a entidades y un bus de eventos; NO contiene reglas.
## Convencion: el equipo 0 defiende el arco -X y ataca el arco +X; el equipo 1 al reves.

signal event_emitted(event: GameEvent)

var ball: Ball
var pitch: Pitch
var camera: MatchCamera
var footballers: Array[Footballer] = []
var keepers: Array = []          # Goalkeeper (se tipa como Array para evitar dependencia circular)
var match_time: float = 0.0
var tick: int = 0
## Si es false, los futbolistas ignoran la entrada (saque, celebracion, fin de partido).
var input_enabled: bool = true
## Segundos seguidos que la pelota lleva practicamente parada y sin que nadie la sostenga. Lo actualiza MatchManager
## y lo usa la IA para romper un atasco: si la jugada se muere, el mas cercano de cada equipo va a buscarla.
var ball_stall_seconds: float = 0.0
## Posesion: UN solo dueno de la pelota a la vez. Se gana tocandola (control, robo, intercepcion) y se pierde cuando la
## pelota se aleja de su control o la toca otro. Mientras tiene dueno, nadie mas conduce esa pelota: el rival solo
## puede quitarsela con una entrada o cortar un toque largo. Asi la posesion es clara (se ve en el aro bajo el portador)
## y la pelota no rebota de pie en pie en los barullos.
var possessor: Footballer = null
## Equipo de campo que maneja la persona (-1 si ninguno). Con la pelota en ese equipo decide siempre la persona: la IA
## de sus companeros nunca pasa ni patea (MatchScene le da el control a quien la recibe).
var human_team: int = -1
var possessor_since: float = 0.0
## Equipo que tuvo la pelota por ultima vez con dueno (fase de juego: ataque / defensa), -1 al inicio.
var phase_team: int = -1
var _poss_frame: int = -1
## Organizacion colectiva por equipo (TeamBrain), creada a demanda por la IA.
var brains: Array = [null, null]

## Actualiza el dueno de la pelota (una vez por paso de fisica, la llame quien la llame).
func update_possession() -> void:
	var fr: int = Engine.get_physics_frames()
	if fr == _poss_frame:
		return
	_poss_frame = fr
	var b: Ball = ball
	if b == null:
		return
	if b.is_held():
		possessor = null
		phase_team = int(b.holder.get("team")) if b.holder != null and b.holder.get("team") != null else phase_team
		return
	if possessor != null and is_instance_valid(possessor):
		var d: float = Vector2(possessor.global_position.x - b.global_position.x, possessor.global_position.z - b.global_position.z).length()
		var touched_by_other: bool = b.last_toucher != possessor
		if not touched_by_other and d <= possessor.ball_handler.possession_radius() * 1.45 and b.global_position.y < 0.9:
			return
		possessor = null
	var lt: Footballer = b.last_toucher as Footballer
	if lt != null and is_instance_valid(lt) and b.global_position.y < 0.7:
		var d2: float = Vector2(lt.global_position.x - b.global_position.x, lt.global_position.z - b.global_position.z).length()
		var rel: float = Vector2(b.linear_velocity.x - lt.velocity.x, b.linear_velocity.z - lt.velocity.z).length()
		# La pelota es suya si la tiene cerca y va con el (no si acaba de patearla lejos).
		if d2 <= lt.ball_handler.possession_radius() and rel < 6.0:
			possessor = lt
			possessor_since = match_time
			phase_team = lt.team

## Pelota sin dueno (rodando, en el aire, rebote): cualquiera puede ir a buscarla y tocarla.
func ball_is_loose() -> bool:
	update_possession()
	return possessor == null

## Pelota muerta (balon parado en preparacion): solo `restart_taker` puede tocarla; la IA no la persigue.
var dead_ball: bool = false
var restart_taker: Node = null

## true si `who` no puede tocar la pelota ahora (balon parado de otro).
func ball_locked_for(who: Node) -> bool:
	return dead_ball and who != restart_taker

## Actualiza el contador de pelota muerta (lo llama MatchManager cada paso de fisica mientras se juega).
func update_ball_stall(delta: float) -> void:
	if ball != null and not ball.is_held() and ball.linear_velocity.length() < 0.6:
		ball_stall_seconds += delta
	else:
		ball_stall_seconds = 0.0

func emit_event(e: GameEvent) -> void:
	e.tick = tick
	e.match_time = match_time
	event_emitted.emit(e)

func register_footballer(f: Footballer) -> void:
	if not footballers.has(f):
		footballers.append(f)

func unregister_footballer(f: Footballer) -> void:
	footballers.erase(f)

func teammates_of(p: Footballer) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in footballers:
		if f != p and f.team == p.team:
			out.append(f)
	return out

func opponents_of(p: Footballer) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in footballers:
		if f.team != p.team:
			out.append(f)
	return out

func opponents_of_team(team: int) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in footballers:
		if f.team != team:
			out.append(f)
	return out

## Arco que ataca un equipo: el equipo 0 ataca +X.
func attacking_goal(team: int) -> Goal:
	return pitch.get_goal(1 if team == 0 else -1)

func defending_goal(team: int) -> Goal:
	return pitch.get_goal(-1 if team == 0 else 1)

func register_keeper(k: Node) -> void:
	if not keepers.has(k):
		keepers.append(k)

func unregister_keeper(k: Node) -> void:
	keepers.erase(k)

func keeper_defending(team: int) -> Node:
	for k in keepers:
		if int(k.get("team")) == team:
			return k
	return null

## Jugador (no arquero) del equipo dado mas cercano a un punto.
func nearest_footballer(pos: Vector3, team: int = -1, exclude: Footballer = null) -> Footballer:
	var best: Footballer = null
	var best_d: float = INF
	for f in footballers:
		if f == exclude or (team >= 0 and f.team != team):
			continue
		var d: float = Vector2(f.global_position.x - pos.x, f.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = f
	return best

## Convierte un vector 2D de pantalla en direccion de mundo usando la camara si existe.
func screen_to_world(v: Vector2) -> Vector3:
	if camera != null and is_instance_valid(camera):
		return camera.screen_to_world_dir(v)
	return Vector3(v.x, 0.0, v.y)
