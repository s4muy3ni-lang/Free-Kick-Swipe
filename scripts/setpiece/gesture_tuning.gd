class_name GestureTuning
extends Resource
## Coeficientes del sistema de disparo por trazo (ShotGesture -> GestureShotModel). Todo es configurable desde el panel de
## diagnostico del juego (sin recompilar) y se guarda en user://gesture_tuning.tres. Los valores por defecto son un punto
## de partida medido en escritorio con trazos sinteticos (tests/test_shot_gesture.gd): hay que calibrarlos en el telefono.
## Unidades: las distancias del trazo van en ALTURAS DE PANTALLA (independiente de la resolucion y de la densidad de pixeles)
## y las velocidades en alturas de pantalla por segundo.

const USER_PATH := "user://gesture_tuning.tres"

@export_group("Captura y filtro")
## Suavizado exponencial de los puntos (0 = sin filtro, 1 = no se mueve): reduce el temblor del dedo.
@export_range(0.0, 0.9) var smoothing: float = 0.35
## Distancia minima entre muestras (alturas de pantalla): ignora micro movimientos involuntarios.
@export_range(0.0, 0.02) var min_step: float = 0.004
## Muestras como maximo (al llenarse se diezma de a dos).
@export_range(16, 256) var max_samples: int = 96
## Largo minimo para que el trazo sea un tiro (alturas de pantalla).
@export_range(0.02, 0.3) var min_length: float = 0.07

@export_group("Potencia (velocidad del dedo)")
## Velocidad del dedo para potencia minima y maxima (alturas de pantalla / s).
@export_range(0.2, 3.0) var speed_slow: float = 0.9
@export_range(1.0, 10.0) var speed_fast: float = 4.4
## Peso de la velocidad maxima frente a la media (un latigazo final cuenta).
@export_range(0.0, 1.0) var peak_weight: float = 0.35
## Curva de respuesta: potencia = min + (max - min) * (1 - exp(-g x)) / (1 - exp(-g)); g > 0 satura los trazos muy rapidos.
@export_range(0.05, 4.0) var power_curve: float = 1.2
@export_range(0.0, 0.5) var power_min: float = 0.05
@export_range(0.5, 1.0) var power_max: float = 1.0

@export_group("Altura")
## Trazo que termina bajando: baja el punto de llegada (m) y agrega efecto hacia delante (la pelota cae).
@export_range(0.0, 1.5) var descend_drop: float = 0.6
## Trazo que termina subiendo con fuerza: sube el punto de llegada (m).
@export_range(0.0, 1.0) var ascend_lift: float = 0.25

@export_group("Efecto (curvatura)")
## Curvatura por debajo de la cual no hay efecto (zona muerta).
@export_range(0.0, 0.1) var curve_deadzone: float = 0.025
## Giro (rad/s) por unidad de curvatura y giro maximo.
@export_range(50.0, 600.0) var spin_gain: float = 280.0
@export_range(10.0, 150.0) var spin_max: float = 70.0
## Efecto hacia delante (topspin, rad/s) de los tiros potentes y altos.
@export_range(0.0, 40.0) var topspin: float = 18.0

@export_group("Precision")
## Error (grados) base, por potencia (x potencia^2), por trazo irregular (x (1 - suavidad)) y por trazo corto.
@export_range(0.0, 2.0) var error_base: float = 0.35
@export_range(0.0, 4.0) var error_power: float = 1.5
@export_range(0.0, 5.0) var error_rough: float = 1.6
@export_range(0.0, 3.0) var error_short: float = 0.8
## Largo (alturas de pantalla) a partir del cual el trazo da el control completo de la direccion.
@export_range(0.1, 1.0) var length_full: float = 0.45
## Irregularidad de referencia (rad de cambio de direccion entre muestras, RMS) que deja la suavidad en 0.
@export_range(0.05, 1.0) var rough_ref: float = 0.35

@export_group("Tipos de disparo")
## Potencia por debajo de la cual un trazo alto es un globo / vaselina.
@export_range(0.05, 0.5) var lob_max_power: float = 0.2
## Altura de llegada (m) por encima de la cual el tiro es «elevado» o globo.
@export_range(0.8, 2.4) var high_height: float = 1.35
## Curvatura a partir de la cual el tiro es «con efecto».
@export_range(0.02, 0.3) var curl_min: float = 0.07
## Largo maximo de un tiro «rapido de corta distancia» (alturas de pantalla).
@export_range(0.05, 0.4) var snap_max_length: float = 0.2
## Suavidad minima de un tiro «de precision».
@export_range(0.5, 1.0) var precision_smoothness: float = 0.85

static var _current: GestureTuning = null

## Parametros activos (los guardados por el usuario o los de por defecto).
static func current() -> GestureTuning:
	if _current == null:
		if ResourceLoader.exists(USER_PATH):
			var r: Resource = ResourceLoader.load(USER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
			if r is GestureTuning:
				_current = r
		if _current == null:
			_current = GestureTuning.new()
	return _current

static func save_current() -> int:
	return ResourceSaver.save(current(), USER_PATH)

static func reset_current() -> void:
	_current = GestureTuning.new()
	if FileAccess.file_exists(USER_PATH):
		DirAccess.remove_absolute(USER_PATH)

## Parametros editables desde el panel de diagnostico: [nombre, minimo, maximo, paso].
const EDITABLE := [
	["smoothing", 0.0, 0.9, 0.05], ["speed_slow", 0.2, 3.0, 0.1], ["speed_fast", 1.0, 10.0, 0.1],
	["peak_weight", 0.0, 1.0, 0.05], ["power_curve", 0.05, 4.0, 0.05], ["descend_drop", 0.0, 1.5, 0.05],
	["curve_deadzone", 0.0, 0.1, 0.005], ["spin_gain", 50.0, 600.0, 10.0], ["spin_max", 10.0, 150.0, 5.0],
	["error_power", 0.0, 4.0, 0.1], ["error_rough", 0.0, 5.0, 0.1], ["length_full", 0.1, 1.0, 0.05],
]
