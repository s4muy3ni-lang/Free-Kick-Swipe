class_name ScrollTap
extends RefCounted
## Listas con scroll en el telefono (pedido del usuario 2026-11-12: «no me deja hacer scroll sobre los iconos de los
## minijuegos»). En Godot un boton (y un panel) se queda con el toque y el ScrollContainer no recibe el arrastre: la
## lista solo se movia tocando los huecos entre tarjetas. watch(scroll) arregla toda la lista:
##  - todo lo que se agrega a su contenido deja pasar el arrastre (mouse_filter PASS en vez de STOP), salvo los campos de
##    texto, los deslizadores y las listas con scroll propias;
##  - un toque que termino arrastrando la lista no aprieta el boton que quedo bajo el dedo (se ignora el «pressed»
##    mientras arrastra y hasta TAP_GRACE_MS despues).

const TAP_GRACE_MS := 200

## Prepara un ScrollContainer (una vez): lo que ya tiene y lo que se le agregue despues.
static func watch(scroll: ScrollContainer) -> void:
	if scroll.has_meta("tap_watch"):
		return
	scroll.set_meta("tap_watch", true)
	scroll.scroll_started.connect(func() -> void: scroll.set_meta("tap_drag", true))
	scroll.scroll_ended.connect(func() -> void:
		scroll.set_meta("tap_drag", false)
		scroll.set_meta("tap_end", Time.get_ticks_msec()))
	var added := func(n: Node) -> void:
		if is_instance_valid(scroll) and scroll.is_ancestor_of(n):
			# Al final del cuadro: las conexiones del boton ya estan hechas.
			(func() -> void: ScrollTap.relax(n)).call_deferred()
	if scroll.is_inside_tree():
		scroll.get_tree().node_added.connect(added)
		scroll.tree_exiting.connect(func() -> void:
			if scroll.get_tree().node_added.is_connected(added):
				scroll.get_tree().node_added.disconnect(added), CONNECT_ONE_SHOT)
	else:
		scroll.tree_entered.connect(func() -> void:
			if not scroll.get_tree().node_added.is_connected(added):
				scroll.get_tree().node_added.connect(added))
		scroll.tree_exiting.connect(func() -> void:
			if scroll.get_tree().node_added.is_connected(added):
				scroll.get_tree().node_added.disconnect(added))
	relax(scroll)

## Deja pasar el arrastre en n y sus hijos, y protege sus botones del toque que arrastro la lista.
static func relax(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is Control and not _keeps_input(n as Control):
		if (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		if n is BaseButton:
			_guard(n as BaseButton)
	for c in n.get_children():
		relax(c)

static func _keeps_input(c: Control) -> bool:
	return c is ScrollContainer or c is LineEdit or c is TextEdit or c is Range or c is ItemList or c is Tree

## El «pressed» del boton pasa por blocked(): si la lista se arrastro, no se aprieta.
static func _guard(b: BaseButton) -> void:
	if b.has_meta("tap_guard"):
		return
	b.set_meta("tap_guard", true)
	for conn in b.pressed.get_connections():
		var cb: Callable = conn["callable"]
		b.pressed.disconnect(cb)
		b.pressed.connect(func() -> void:
			if not ScrollTap.blocked(b):
				cb.call())

## true si el boton esta en una lista que se esta arrastrando o se acaba de arrastrar.
static func blocked(c: Node) -> bool:
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer and p.has_meta("tap_watch"):
			if bool(p.get_meta("tap_drag", false)):
				return true
			return Time.get_ticks_msec() - int(p.get_meta("tap_end", -100000)) < TAP_GRACE_MS
		p = p.get_parent()
	return false
