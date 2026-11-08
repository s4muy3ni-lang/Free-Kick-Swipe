extends Node
## Autoload "Sfx": efectos de sonido del partido (sintetizados por tools/audio/make_sfx.py, en assets/audio/).
## Un grupo de reproductores sin posicion (en el movil el sonido 3D no aporta) y un ambiente de publico en bucle.
## Lo conecta MatchScene a la pelota y a los eventos del partido: los golpes (tambien los del arquero) suenan con la
## fuerza del impulso real (Ball.impulse), el poste, la red y los botes con su velocidad.

const SOUNDS := [&"kick_hard", &"kick_soft", &"touch", &"bounce", &"post", &"net", &"whistle_short", &"whistle_long",
	&"glove", &"cheer", &"ooh"]
const VOICES := 10
## Interruptor (Tuning.sound_on, menu de pausa; las pruebas no lo necesitan apagar: sin audio real no suena nada).
var enabled: bool = true
var _crowd_wanted: bool = false

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _crowd: AudioStreamPlayer = null
## Ultimo sonido de cada tipo (s de reloj): evita que un mismo golpe suene dos veces en el mismo instante.
var _last := {}

func _ready() -> void:
	enabled = Tuning.sound_on
	for n in SOUNDS:
		var s: AudioStream = load("res://assets/audio/%s.wav" % n) as AudioStream
		if s != null:
			_streams[n] = s
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var loop: AudioStreamWAV = load("res://assets/audio/crowd_loop.wav") as AudioStreamWAV
	if loop != null:
		loop = loop.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * float(loop.mix_rate))
		_crowd = AudioStreamPlayer.new()
		_crowd.stream = loop
		_crowd.volume_db = -20.0
		add_child(_crowd)

## Reproduce un efecto. volume: 0..1 (escala lineal), pitch: tono (1 = original).
func play(name: StringName, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not enabled or not _streams.has(name) or volume <= 0.01:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < 0.03:
		return
	_last[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = linear_to_db(clampf(volume, 0.0, 1.5))
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()

## Ambiente de publico (bucle) mientras hay partido.
func crowd(on: bool) -> void:
	_crowd_wanted = on
	if _crowd == null:
		return
	if on and enabled and not _crowd.playing:
		_crowd.play()
	elif (not on or not enabled) and _crowd.playing:
		_crowd.stop()

## Enciende o apaga todo el sonido (el publico vuelve si hay partido).
func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		for p in _players:
			p.stop()
	crowd(_crowd_wanted)

# --- Conexiones ---------------------------------------------------------------------------------------------------

## Conecta los sonidos de la pelota (golpes, botes, poste, red).
func watch_ball(ball: Ball) -> void:
	if ball == null:
		return
	if not ball.impulse.is_connected(_on_impulse):
		ball.impulse.connect(_on_impulse)
		ball.floor_bounce.connect(_on_bounce)
		ball.hit_goal_frame.connect(_on_post)
		ball.net_hit.connect(_on_net)

## Golpe a la pelota: toque de conduccion, pase o tiro segun el cambio de velocidad (m/s) que le dio el impulso.
func _on_impulse(actor: Node, dv: float, speed: float) -> void:
	var s: Array = impulse_sound(actor is Goalkeeper, dv, speed)
	if not s.is_empty():
		play(s[0], s[1], randf_range(0.94, 1.06) * float(s[2]))

## Sonido de un golpe: [nombre, volumen, tono] o [] si no suena (un apoyo de la suela, un roce). Guantes del arquero;
## toque de conduccion (cambio de velocidad < 4.5 m/s); pase o tiro flojo (sale a < 15 m/s); tiro fuerte.
static func impulse_sound(keeper: bool, dv: float, speed: float) -> Array:
	if keeper:
		return [&"glove", clampf(dv / 12.0, 0.4, 1.0), 1.0]
	if dv < 0.6:
		return []
	if dv < 4.5:
		return [&"touch", clampf(dv / 4.5, 0.25, 0.7), 1.0]
	if speed < 15.0:
		return [&"kick_soft", clampf(speed / 15.0, 0.45, 1.0), 1.0]
	return [&"kick_hard", clampf(speed / 25.0, 0.7, 1.3), 0.97]

func _on_bounce(_pos: Vector3, speed: float) -> void:
	if speed > 2.0:
		play(&"bounce", clampf(speed / 9.0, 0.15, 0.8), randf_range(0.9, 1.1))

func _on_post(_pos: Vector3, speed: float) -> void:
	play(&"post", clampf(speed / 18.0, 0.35, 1.2))
	if speed > 8.0:
		play(&"ooh", 0.8)

func _on_net(speed: float) -> void:
	play(&"net", clampf(speed / 20.0, 0.3, 1.1), randf_range(0.95, 1.05))

## Sonidos de los eventos del partido: silbatos, festejo del gol, atajadas.
func on_event(e: GameEvent) -> void:
	match e.type:
		GameEvent.Type.KICKOFF, GameEvent.Type.FOUL:
			play(&"whistle_short", 0.8)
		GameEvent.Type.OUT_OF_PLAY:
			play(&"whistle_short", 0.5)
		GameEvent.Type.GOAL:
			play(&"cheer", 1.0)
			play(&"whistle_short", 0.7)
		GameEvent.Type.SAVE, GameEvent.Type.KEEPER_CATCH:
			play(&"glove", 0.9)
			play(&"ooh", 0.7)
		GameEvent.Type.MATCH_END:
			play(&"whistle_long", 0.9)

