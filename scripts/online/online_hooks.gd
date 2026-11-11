class_name OnlineHooks
extends RefCounted
## Puente entre el juego local (progreso, logros, partidas offline) y la cola de sincronizacion del autoload Online.
## Se llama desde funciones estaticas: busca el autoload en el arbol (si no esta, p. ej. en una herramienta, no hace nada).
## Solo se informa QUE paso (fuente, medalla, si gano): el servidor calcula el premio y aplica topes.

static var enabled: bool = true

static func reward(source: String, payload: Dictionary) -> void:
	if not enabled:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var online: Node = tree.root.get_node_or_null("Online")
	if online != null and online.has_method("queue_reward"):
		online.queue_reward(source, payload)
