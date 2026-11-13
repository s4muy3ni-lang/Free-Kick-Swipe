class_name KeeperReach
extends RefCounted
## Alcance fisico de la estirada del arquero (pedido del usuario: «la deteccion debe basarse en el alcance real… si la
## pelota va demasiado pegada al angulo y supera el alcance fisico de la estirada, sera gol aunque pertenezca al mismo
## sector»). Lo usan igual el arquero del usuario, el de la IA, el duelo local y el servidor (LocalBackend y la funcion
## SQL keeper_reachable, con las mismas constantes): ninguna atajada imposible.
##
## Modelo (medido con las estiradas del banco y la guia de la estirada asegurada de SpKeeper):
##  - alcance lateral al CENTRO de la pelota desde donde esta parado el arquero al salir el tiro: LOW hasta la altura
##    KNEE_Y (la estirada de costado llega lejos a media altura y al piso), bajando en linea hasta BAR a la altura del
##    travesaño (2,44 m): arriba y pegado al palo, el angulo, no llega nadie;
##  - el tiempo que tarda la pelota en llegar a la linea (mas lo que se anticipo si se jugo antes del golpe) achica ese
##    alcance: con menos de T_REACT no arranca y recien con T_FULL llega estirado del todo; nunca baja de F_MIN (lo que
##    tiene al alcance de las manos sin tirarse);
##  - los atributos del arquero (reflejos, alcance) lo escalan poco, dentro de limites (scale, react).

const LOW := 3.5
const KNEE_Y := 1.2
const BAR := 2.4
const BAR_Y := 2.44
const T_REACT := 0.12
const T_FULL := 0.65
const F_MIN := 0.5
## Limites de los atributos: el alcance cambia a lo sumo un 6 % y la reaccion 0,04 s.
const SCALE_LIMITS := Vector2(0.94, 1.06)
const REACT_LIMITS := Vector2(-0.04, 0.04)

## Alcance lateral (m) al centro de la pelota a la altura y, con todo el tiempo.
static func lateral_at(y: float) -> float:
	if y <= KNEE_Y:
		return LOW
	return maxf(LOW + (BAR - LOW) * (y - KNEE_Y) / (BAR_Y - KNEE_Y), 0.0)

## Fraccion del alcance que le da el tiempo disponible t (s). react > 0 = mas lento (reacciona tarde).
static func time_factor(t: float, react: float = 0.0) -> float:
	var t0: float = T_REACT + clampf(react, REACT_LIMITS.x, REACT_LIMITS.y)
	return clampf((t - t0) / (T_FULL - t0), F_MIN, 1.0)

## Alcance lateral (m) a la altura y con t segundos.
static func reach(y: float, t: float, scale: float = 1.0, react: float = 0.0) -> float:
	return lateral_at(y) * time_factor(t, react) * clampf(scale, SCALE_LIMITS.x, SCALE_LIMITS.y)

## El punto p del plano del arco (y = alto, z = ancho) esta al alcance de un arquero parado en keeper_z con t segundos.
static func reachable(p: Vector3, keeper_z: float, t: float, scale: float = 1.0, react: float = 0.0) -> bool:
	if p == Vector3.INF or p.y < -0.05:
		return false
	return absf(p.z - keeper_z) <= reach(p.y, t, scale, react)

## Detalle para diagnostico y pruebas: distancia lateral, alcance, factor de tiempo y si llega.
static func explain(p: Vector3, keeper_z: float, t: float, scale: float = 1.0, react: float = 0.0) -> Dictionary:
	var d: float = absf(p.z - keeper_z) if p != Vector3.INF else INF
	var r: float = reach(p.y, t, scale, react) if p != Vector3.INF else 0.0
	return {"d": d, "reach": r, "time": t, "factor": time_factor(t, react), "ok": reachable(p, keeper_z, t, scale, react)}

## Tiempo (s) que tarda la trayectoria traj (muestras cada step s desde el golpe) en cruzar la linea x = goal_x, o INF.
static func time_to_line(traj: PackedVector3Array, step: float, goal_x: float) -> float:
	if traj.size() < 2:
		return INF
	var sgn: float = signf(goal_x - traj[0].x)
	for i in range(1, traj.size()):
		if (traj[i].x - goal_x) * sgn >= 0.0:
			var a: float = (goal_x - traj[i - 1].x) / maxf(absf(traj[i].x - traj[i - 1].x), 1e-6) * sgn
			return (float(i - 1) + clampf(a, 0.0, 1.0)) * step
	return INF
