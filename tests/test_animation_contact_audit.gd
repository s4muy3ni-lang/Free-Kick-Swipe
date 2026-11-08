extends TestCase
## Auditoria de las animaciones que tocan la pelota (datos MEDIDOS al convertir el pack, no supuestos): para cada clip
## con contacto, el pie que golpea, el instante de contacto, donde esta la punta del pie respecto al cuerpo, su
## velocidad, el desplazamiento de raiz y que sistema lo usa. Comprueba que los clips de pase/tiro que usa el juego
## tienen un contacto valido (pie bajo, por delante del cuerpo, dentro del clip).
## Con la variable AUDIT_OUT escribe el informe en markdown (docs/technical-index/ANIMATION_CONTACT_AUDIT.md).

## Sistema del modo 1 (pack de Mixamo / Tripo), descartado como modo de juego pero todavia en el codigo: se prueba en su modo.
func gameplay_mode() -> int:
	return 1

const BALL_ROLES := ["pase_tiro", "volea", "cabezazo", "practica", "recepcion", "marcha_con_balon", "malabares", "habilidad", "entrada"]

func _ids() -> Array:
	return Array(PackLibrary.field().get_animation_list()) + Array(PackLibrary.keeper().get_animation_list())

## Nombres de clip que aparecen en el codigo (para decir quien los usa).
func _code_text() -> String:
	var out := ""
	for dir in ["res://scripts/player", "res://scripts/animation", "res://scripts/gameplay", "res://scripts/goalkeeper", "res://scripts/ai"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".gd"):
				out += FileAccess.get_file_as_string(dir + "/" + f) + "\n"
	return out

func test_ball_contact_clips_are_valid_and_reported() -> void:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return
	var code: String = _code_text()
	var lines: Array[String] = []
	lines.append("# Auditoría de animaciones con pelota (generada por `tests/test_animation_contact_audit.gd`)")
	lines.append("")
	lines.append("Datos medidos sobre el esqueleto al convertir el pack (`PackLibrary.meta`). Posición de la punta del pie en el")
	lines.append("contacto: adelante / arriba / derecha (m) respecto al origen del jugador. «Usado por»: dónde aparece el nombre del")
	lines.append("clip (o su base, sin `_mirror`) en el código.")
	lines.append("")
	lines.append("## Clips con contacto medido")
	lines.append("")
	lines.append("| Clip | Función | Pie | Contacto (s) / duración | Punta del pie (adel., arriba, der.) | Velocidad del pie (m/s) | Raíz (m) | Usado por |")
	lines.append("|---|---|---|---|---|---|---|---|")
	var contact_count := 0
	for id in _ids():
		var m: Dictionary = PackLibrary.meta(StringName(id))
		if not m.has("contact"):
			continue
		contact_count += 1
		var c: Dictionary = m["contact"]
		var pos: Vector3 = c["pos"]
		var base: String = String(id).replace("_mirror", "")
		var used: String = "sí" if code.find("\"%s\"" % base) >= 0 or code.find("&\"%s\"" % base) >= 0 else "no"
		var rt: Vector2 = m.get("root_total", Vector2.ZERO)
		lines.append("| `%s` | %s | %s | %.2f / %.2f | %.2f, %.2f, %.2f | %.1f | %.2f | %s |" % [id, String(m.get("role", "")), "derecho" if int(c["foot"]) == 1 else "izquierdo",
			float(c["time"]), float(m.get("duration", 0.0)), pos.x, pos.y, pos.z, float(c.get("speed", 0.0)), rt.length(), used])
	lines.append("")
	lines.append("## Clips de pelota sin contacto de pie medido")
	lines.append("")
	lines.append("| Función | Clips (duración s, raíz m) |")
	lines.append("|---|---|")
	var groups := {}
	for id in _ids():
		var m2: Dictionary = PackLibrary.meta(StringName(id))
		var r: String = String(m2.get("role", ""))
		if m2.has("contact") or not BALL_ROLES.has(r):
			continue
		if not groups.has(r):
			groups[r] = []
		groups[r].append("`%s` (%.2f, %.2f)" % [id, float(m2.get("duration", 0.0)), (m2.get("root_total", Vector2.ZERO) as Vector2).length()])
	for r in groups.keys():
		lines.append("| %s | %s |" % [r, ", ".join(groups[r])])
	lines.append("")
	lines.append("No hay en el pack clips de pisada (parar la pelota con la suela), de toque de empuje aislado ni de despeje: la")
	lines.append("parada y los toques de conducción los da el pie de la marcha (`BallHandler._foot_strike`) y el despeje usa los")
	lines.append("clips de golpeo.")
	var out_path: String = OS.get_environment("AUDIT_OUT")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
		note("informe escrito en %s" % out_path)
	note("%d clips con contacto medido" % contact_count)
	check(contact_count >= 4, "hay clips con contacto medido (%d)" % contact_count)
	# Los clips de golpeo que usa el juego tienen un contacto valido.
	for kind in AnimationCatalog.KICKS.keys():
		for cand in AnimationCatalog.kick_candidates(kind):
			var c2: Dictionary = cand["contact"]
			var p2: Vector3 = c2["pos"]
			var dur: float = float(PackLibrary.meta(cand["clip"]).get("duration", 0.0))
			check(p2.y <= Tuning.player.kick_foot_max_height + 0.05 and p2.x > 0.0 and float(c2["time"]) > 0.05 and float(c2["time"]) < dur,
				"%s / %s: contacto valido (t=%.2f s de %.2f, punta a %.2f m delante y %.2f m de alto)" % [kind, cand["clip"], c2["time"], dur, p2.x, p2.y])
