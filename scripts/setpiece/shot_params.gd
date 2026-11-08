class_name ShotParams
extends RefCounted
## Parametros de un disparo calculados a partir del gesto (GestureShotModel). Lo usan por igual la vista previa de la
## trayectoria, el tiro real, la eleccion del golpeo y el panel de diagnostico.

## Potencia 0..1 (velocidad del dedo con su curva de respuesta).
var power: float = 0.0
## Direccion horizontal del tiro (unitaria).
var direction := Vector3(1, 0, 0)
## Angulo de salida (grados) que resulta de la fisica para llegar al objetivo.
var launch_angle: float = 0.0
## Efecto lateral (rad/s alrededor del eje vertical; + la pelota se cierra hacia la izquierda del tiro).
var lateral_spin: float = 0.0
## Giro completo (lateral + efecto hacia delante).
var spin := Vector3.ZERO
## Precision 0..1 y error angular (grados, desviacion tipica) que se aplica al soltar.
var accuracy: float = 1.0
var error_deg: float = 0.0
var gesture_length: float = 0.0
var average_speed: float = 0.0
var peak_speed: float = 0.0
## potente_raso, colocado, globo, con_efecto, rapido_corto, elevado, precision, normal (o invalido).
var gesture_type: String = "normal"
## Punto del plano del arco al que apunta el gesto, velocidad de salida (m/s), curvatura y suavidad del trazo.
var target := Vector3.ZERO
var speed: float = 0.0
var curve: float = 0.0
var smoothness: float = 1.0
var vertical: float = 0.0
## Resultado de la fisica (ShotSolver): velocidad sin error, trayectoria, cruce con el arco y su clase prevista.
var velocity := Vector3.ZERO
var trajectory := PackedVector3Array()
var crossing := Vector3.INF
var predicted_class: String = ""
## Familia de golpeo pedida (ShotCatalog.Kind) y preferencias para elegir el clip.
var kind: int = 1
var prefer_short: bool = false
var curled: bool = false

func to_dict() -> Dictionary:
	return {"power": power, "direction": direction, "launch_angle": launch_angle, "lateral_spin": lateral_spin,
		"accuracy": accuracy, "error_deg": error_deg, "gesture_length": gesture_length, "average_speed": average_speed,
		"peak_speed": peak_speed, "gesture_type": gesture_type, "target": target, "speed": speed, "curve": curve,
		"smoothness": smoothness, "predicted_class": predicted_class}
