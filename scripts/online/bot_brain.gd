class_name BotBrain
extends RefCounted
## Decisiones de un rival IA (no toca la fisica: patea con el mismo modelo de tiro que el usuario y ataja con el mismo
## arquero). Cada personalidad cambia como decide, y la habilidad (0..1, adaptativa) cuanto se equivoca:
##  - error de punteria en grados (mas habilidad, menos error; nunca cero: no hay tiros perfectos),
##  - preferencia de esquinas, altura y potencia, con variacion (no repite secuencias),
##  - como arquero: probabilidad de leer al tirador; nunca conoce la direccion real del tiro antes del golpe.

const STYLE := {
	"principiante": {"err": 1.6, "corner": 0.35, "high": 0.25, "power": 0.55, "read": 0.25, "risk": 0.2},
	"tranquilo": {"err": 1.0, "corner": 0.5, "high": 0.3, "power": 0.6, "read": 0.4, "risk": 0.3},
	"agresivo": {"err": 1.2, "corner": 0.6, "high": 0.55, "power": 0.85, "read": 0.35, "risk": 0.7},
	"tecnico": {"err": 0.8, "corner": 0.75, "high": 0.35, "power": 0.6, "read": 0.5, "risk": 0.5},
	"impredecible": {"err": 1.1, "corner": 0.55, "high": 0.45, "power": 0.7, "read": 0.4, "risk": 0.6},
	"competitivo": {"err": 0.9, "corner": 0.7, "high": 0.4, "power": 0.75, "read": 0.5, "risk": 0.5},
	"experto": {"err": 0.65, "corner": 0.85, "high": 0.4, "power": 0.75, "read": 0.6, "risk": 0.55},
}

var bot: Dictionary
var rng := RandomNumberGenerator.new()
var style: Dictionary

func _init(b: Dictionary) -> void:
	bot = b
	rng.seed = int(b.get("seed", 1))
	style = STYLE.get(String(b.get("personality", "tranquilo")), STYLE["tranquilo"])

func skill() -> float:
	return clampf(float(bot.get("skill", 0.5)), 0.05, 0.98)

## Error de punteria (grados) para ShotSolver.perturb: 3,5 grados con habilidad 0 hasta ~0,6 con habilidad 1, por el
## estilo; nunca cero.
func aim_error_deg() -> float:
	return maxf(lerpf(3.5, 0.6, skill()) * float(style["err"]), 0.4)

## Destino del penal (plano del arco, x = goal_x): esquina o centro, alto o bajo, con variacion propia.
func penalty_target(goal_x: float, half_goal: float, goal_h: float) -> Vector3:
	var corner: bool = rng.randf() < float(style["corner"]) * lerpf(0.7, 1.1, skill())
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var z: float = side * (rng.randf_range(half_goal * 0.55, half_goal - 0.35) if corner else rng.randf_range(0.0, 1.2))
	var high: bool = rng.randf() < float(style["high"])
	var y: float = rng.randf_range(1.35, goal_h - 0.3) if high else rng.randf_range(0.25, 0.9)
	return Vector3(goal_x, y, z)

func shot_power() -> float:
	return clampf(float(style["power"]) + rng.randf_range(-0.15, 0.15), 0.3, 0.98)

## Como arquero: zona (KeeperZones 0..5) a la que se juega antes del tiro. cue_zone es lo que «lee» del cuerpo del
## tirador (la zona hacia donde apunta su carrera), que puede no ser la del tiro real. Con probabilidad de lectura segun
## estilo y habilidad usa esa lectura; si no, adivina.
func keeper_zone(cue_zone: int) -> int:
	var p_read: float = float(style["read"]) * lerpf(0.6, 1.1, skill())
	if cue_zone >= 0 and rng.randf() < p_read:
		return cue_zone
	return rng.randi_range(0, 5)

## Puntos de un turno de minijuego cuando el bot «juega» sin escena (respaldo; en la partida real el bot patea con la
## fisica del minijuego). max_points = tope del modo.
func minigame_points(max_points: int) -> int:
	var hit: float = lerpf(0.35, 0.85, skill())
	if rng.randf() > hit:
		return 0
	return clampi(int(round(max_points * rng.randf_range(0.3, 1.0) * lerpf(0.6, 1.0, skill()))), 1, max_points)
