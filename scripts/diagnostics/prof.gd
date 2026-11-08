class_name Prof
extends RefCounted
## Medicion del costo de CPU por sistema (tools/perf_probe.tscn): acumula microsegundos por etiqueta mientras `enabled`.
## Apagado (siempre en el juego) cada llamada es una sola comprobacion.

static var enabled: bool = false
## Total acumulado por etiqueta (us) y el de la imagen en curso (lo vacia el medidor en cada imagen).
static var acc: Dictionary = {}
static var calls: Dictionary = {}
static var frame: Dictionary = {}
static var _t0: Dictionary = {}

static func begin(tag: StringName) -> void:
	if enabled:
		_t0[tag] = Time.get_ticks_usec()

static func end(tag: StringName) -> void:
	if enabled and _t0.has(tag):
		var us: int = Time.get_ticks_usec() - int(_t0[tag])
		acc[tag] = int(acc.get(tag, 0)) + us
		calls[tag] = int(calls.get(tag, 0)) + 1
		frame[tag] = int(frame.get(tag, 0)) + us

static func reset() -> void:
	acc.clear()
	calls.clear()
	frame.clear()
	_t0.clear()
