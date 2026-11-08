class_name InputBindings
extends RefCounted
## Esquema comun de acciones para teclado, mando y pantalla tactil. project.godot define las acciones base con
## teclado; aqui se agregan (una sola vez, al arrancar) las acciones nuevas y los controles de mando, de modo que
## todas las fuentes producen las MISMAS acciones de InputMap y el juego no distingue el dispositivo.
##
## Mando (disposicion Xbox / equivalente PlayStation), contextual como en los juegos de futbol de consola:
##   Stick izquierdo / cruceta: mover.            A (X): pase / presion.        X (Cuadrado): tiro / entrada.
##   Y (Triangulo): pase filtrado.                B (Circulo): centro.          RB (R1): sprint.
##   LB (L1): modificador alto (vaselina / elevado). LT (L2): cambio de jugador.  RT (R2): regate (ruleta).
##   Start: pausa.

## Acciones nuevas con su tecla (codigo fisico) por defecto.
const EXTRA_KEYS := {&"through_pass": KEY_O, &"cross": KEY_H, &"tackle": KEY_N}

## Botones de mando por accion (JoyButton). Una accion puede compartir boton con otra: el juego decide por contexto
## (con la pelota el boton A pasa; sin ella presiona).
const JOY_BUTTONS := {
	&"pass": [JOY_BUTTON_A], &"press": [JOY_BUTTON_A],
	&"shoot": [JOY_BUTTON_X], &"tackle": [JOY_BUTTON_X],
	&"through_pass": [JOY_BUTTON_Y], &"cross": [JOY_BUTTON_B],
	&"sprint": [JOY_BUTTON_RIGHT_SHOULDER], &"lob": [JOY_BUTTON_LEFT_SHOULDER],
	&"pause_game": [JOY_BUTTON_START],
	&"move_left": [JOY_BUTTON_DPAD_LEFT], &"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP], &"move_down": [JOY_BUTTON_DPAD_DOWN],
}
## Ejes de mando por accion: [eje, signo]. Los gatillos se usan como botones.
const JOY_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0], &"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"switch_player": [JOY_AXIS_TRIGGER_LEFT, 1.0], &"skill": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

static var _done: bool = false

## Registra las acciones y eventos que falten. Idempotente.
static func ensure() -> void:
	if _done:
		return
	_done = true
	for action in EXTRA_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
			var k := InputEventKey.new()
			k.physical_keycode = EXTRA_KEYS[action]
			InputMap.action_add_event(action, k)
	for action in JOY_BUTTONS:
		if not InputMap.has_action(action):
			continue
		for b in JOY_BUTTONS[action]:
			var e := InputEventJoypadButton.new()
			e.button_index = b
			if not InputMap.action_has_event(action, e):
				InputMap.action_add_event(action, e)
	for action in JOY_AXES:
		if not InputMap.has_action(action):
			continue
		var m := InputEventJoypadMotion.new()
		m.axis = JOY_AXES[action][0]
		m.axis_value = JOY_AXES[action][1]
		if not InputMap.action_has_event(action, m):
			InputMap.action_add_event(action, m)
