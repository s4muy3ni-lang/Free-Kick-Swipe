class_name UcsParams
extends RefCounted
## Parametros de juego de Ultimate Clash Soccer que usa nuestra IA (modo 4 y comunes). Los VALORES estan COMPROBADOS: los
## lee de su codigo nativo (libMPX.so, funcion que carga la configuracion de juego: cada parametro se pide por nombre con un
## valor por defecto entero, en punto fijo de 4096 = 1.0 cuando es una escala; tabla completa en
## docs/fases/E4_parametros_ucs.csv). El SIGNIFICADO y la unidad salen del nombre y de como encaja en el juego: inferidos
## (la configuracion del servidor de UCS podria cambiar algun valor; no se pudo comprobar sin conexion).
## Sufijo 0/1: el valor con el atributo minimo y con el maximo del jugador (se interpola con la habilidad).

## Cuadros de juego de UCS por segundo (sus tiempos van en cuadros de 60 Hz).
const FPS := 60.0

## MaxActivePresses = 2: como mucho dos jugadores presionan al portador; MaxActiveTackles = 1: solo uno le entra.
const MAX_ACTIVE_PRESSES := 2
const MAX_ACTIVE_TACKLES := 1
## PressureSpeedRate = 3891/4096: el que presiona corre al 95 %.
const PRESSURE_SPEED_RATE := 3891.0 / 4096.0
## InterceptUrgency = 5120/4096: urgencia de quien va a cortar un pase.
const INTERCEPT_URGENCY := 5120.0 / 4096.0

## BotMinKickFrames = 30, BotMaxKickFrames = 120: el portador de la IA decide golpear (pase, tiro) entre 0.5 y 2 s despues
## de tener la pelota (sin presion; con un rival encima, antes).
const BOT_MIN_KICK_S := 30.0 / FPS
const BOT_MAX_KICK_S := 120.0 / FPS

## ResponsePlayerAction0/1 = 40/20 cuadros: tiempo de respuesta de un jugador de la IA a un cambio de jugada.
const RESPONSE_ACTION_S := Vector2(40.0 / FPS, 20.0 / FPS)
## ResponseGKSave0/1 = 15/4 cuadros: tiempo de reaccion del arquero a un tiro.
const RESPONSE_GK_SAVE_S := Vector2(15.0 / FPS, 4.0 / FPS)

## RunAutoMaxRunners = 2: como mucho dos desmarques de ruptura a la vez; RunTimeout = 300 cuadros: un desmarque dura 5 s.
const RUN_AUTO_MAX_RUNNERS := 2
const RUN_TIMEOUT_S := 300.0 / FPS

## WidthOpenPlay = 60: en juego abierto el equipo ocupa el 60 % del ancho (los de banda no van pegados a la linea).
const WIDTH_OPEN_PLAY := 0.60

## UrgencyLooseBallOppoFrames = 30: con un rival a menos de 0.5 s de una pelota suelta, ir a por ella es urgente.
const URGENCY_LOOSE_BALL_OPPO_S := 30.0 / FPS

## Interpola un par (atributo minimo, maximo) con la habilidad 0..1.
static func by_skill(pair: Vector2, skill: float) -> float:
	return lerpf(pair.x, pair.y, clampf(skill, 0.0, 1.0))
