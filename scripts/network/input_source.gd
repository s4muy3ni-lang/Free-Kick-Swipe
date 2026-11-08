class_name InputSource
extends RefCounted
## Origen de intencion para un futbolista. Implementaciones: HumanInput (joystick/teclado/HUD tactil),
## ScriptedInput (pruebas), futura IA y futuro canal de red. El futbolista solo ve InputFrame.

func poll(_footballer: Footballer) -> InputFrame:
	return InputFrame.new()
