extends TestCase
## Inventario MEDIDO de las animaciones del pack (133 FBX de origen, 171 animaciones con los espejos) sobre el
## esqueleto del futbolista: duracion, bucle, raiz, velocidad del cuerpo, pistas que se enlazan con el esqueleto, y la
## trayectoria real de cada pie (FootTrajectory): empujes (pie bajo, delante del cuerpo, avanzando mas rapido que el
## cuerpo = toque de conduccion visible) y apoyos. No se juzga ningun clip por su nombre.
## Con la variable INVENTORY_OUT escribe el informe (docs/technical-index/ANIMATION_INVENTORY.md).

## Sistema del modo 1 (pack de Mixamo / Tripo), descartado como modo de juego pero todavia en el codigo: se prueba en su modo.
func gameplay_mode() -> int:
	return 1

func _ids() -> Array:
	return Array(PackLibrary.field().get_animation_list()) + Array(PackLibrary.keeper().get_animation_list())

func _code_text() -> String:
	var out := ""
	for dir in ["res://scripts/player", "res://scripts/animation", "res://scripts/gameplay", "res://scripts/goalkeeper", "res://scripts/ai", "res://scripts/practice", "res://scripts/referee"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".gd"):
				out += FileAccess.get_file_as_string(dir + "/" + f) + "\n"
	return out

func _visual() -> FootballerVisual:
	var vis := FootballerVisual.new()
	spawn(vis)
	vis.build(FootballerVisual.default_kit(0))
	if vis.anim_tree != null:
		vis.anim_tree.active = false
	return vis

## Resultado medido de un clip: muestras + analisis.
func _measure(vis: FootballerVisual, id: String) -> Dictionary:
	var anim: Animation = PackLibrary.clip(StringName(id))
	var m: Dictionary = PackLibrary.meta(StringName(id))
	var s: Dictionary = FootTrajectory.sample(anim, vis)
	var a: Dictionary = FootTrajectory.analyze(s, FootTrajectory.body_speed(m))
	a["samples"] = s
	a["meta"] = m
	return a

func _fmt_push(e: Dictionary) -> String:
	return "%.2f s %s: %.2f m delante, %.2f m al %s, %.2f m de alto, pie a %.1f m/s, punta girada %+.0f°" % [float(e["t"]), "der." if int(e["foot"]) == 1 else "izq.",
		float(e["fwd"]), absf(float(e["right"])), "costado der." if float(e["right"]) >= 0.0 else "costado izq.", float(e["up"]), float(e["vg"]), float(e.get("yaw", 0.0))]

func test_coordinates_match_the_contact_measured_when_converting() -> void:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return
	var vis := _visual()
	var anim: Animation = PackLibrary.clip(&"Soccer_Pass")
	var c: Dictionary = PackLibrary.meta(&"Soccer_Pass")["contact"]
	var s: Dictionary = FootTrajectory.sample(anim, vis)
	var i: int = int(round(float(c["time"]) / float(s["dt"])))
	var toe: Vector3 = s["toe"][int(c["foot"])][i]
	var ref: Vector3 = c["pos"]
	note("Soccer_Pass t=%.3f: punta medida %s, contacto del conversor %s" % [float(c["time"]), toe, ref])
	check(toe.distance_to(ref) < 0.05, "la medicion coincide con el contacto del conversor (%.3f m)" % toe.distance_to(ref))
	check(int(s["bound"]) == int(s["tracks"]), "todas las pistas se enlazan con el esqueleto (%d/%d)" % [s["bound"], s["tracks"]])

func test_inventory_of_every_clip_with_measured_feet() -> void:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return
	var vis := _visual()
	var code: String = _code_text()
	var rows: Array[String] = []
	var results := {}
	var unbound := 0
	for id in _ids():
		var r: Dictionary = _measure(vis, String(id))
		results[String(id)] = r
		var m: Dictionary = r["meta"]
		var s: Dictionary = r["samples"]
		if int(s["bound"]) != int(s["tracks"]):
			unbound += 1
		var base: String = String(id).replace("_mirror", "")
		var used: String = "sí" if code.find("\"%s\"" % base) >= 0 else "no"
		var pushes: Array = r["pushes"]
		var pl := [0, 0]
		for e in pushes:
			pl[int(e["foot"])] += 1
		var feet: Array = r["feet"]
		rows.append("| `%s` | `%s` | %s | %.2f | %s | %.2f | %.2f | %d/%d | %d / %d | %.2f / %.2f | %.2f / %.2f | %s |" % [id, String(m.get("source", "?")).get_file(),
			String(m.get("role", "")), float(m.get("duration", 0.0)), "sí" if bool(m.get("loop", false)) else "no",
			(m.get("root_total", Vector2.ZERO) as Vector2).length(), float(r["vb"]), s["bound"], s["tracks"], pl[0], pl[1],
			float(feet[0]["max_fwd_low"]), float(feet[1]["max_fwd_low"]), float(feet[0]["min_h"]), float(feet[1]["min_h"]), used])
	note("%d animaciones medidas; %d con pistas sin enlazar" % [results.size(), unbound])
	check(results.size() >= 133, "se midieron todas las animaciones (%d)" % results.size())
	check(unbound == 0, "todas las pistas se enlazan con el esqueleto del jugador (%d clips con pistas sueltas)" % unbound)
	# Clips de marcha con y sin pelota: empujes por ciclo, cadencia y alcance.
	var focus := ["Dribble_2", "Soccer_Idle", "Running_inplace", "Two_Cycle_Sprint_inplace", "jog_forward_inplace", "Jogging_inplace", "Sprint_inplace", "Soccer_Spin", "receive_soccerball", "Receive", "stall_soccerball", "Idle_To_Sprint", "Sprint_Turn"]
	var detail: Array[String] = []
	for id in focus:
		if not results.has(id):
			detail.append("- `%s`: **no existe** en las librerías." % id)
			continue
		var r2: Dictionary = results[id]
		var ev: Array = []
		for e in r2["pushes"]:
			ev.append(_fmt_push(e))
		var plants: Array = r2["plants"]
		var fe: Array = r2["feet"]
		var line := "- `%s` (cuerpo a %.2f m/s, %.2f s): %d empujes%s; %d apoyos; talón hasta %.2f / %.2f m (izq./der.)." % [id, float(r2["vb"]), float(r2["meta"].get("duration", 0.0)),
			(r2["pushes"] as Array).size(), (": " + "; ".join(ev)) if not ev.is_empty() else "", plants.size(), float(fe[0]["heel_max"]), float(fe[1]["heel_max"])]
		detail.append(line)
		note(line)
	var d2: Dictionary = results.get("Dribble_2", {})
	check(not d2.is_empty(), "existe Dribble_2 (marcha con pelota)")
	# Veredicto de conduccion en carrera para todos los clips que avanzan en bucle.
	var verdicts: Array[String] = []
	var dribble_ok: Array = []
	for id in results.keys():
		var rr: Dictionary = results[id]
		if not bool(rr["meta"].get("loop", false)) or float(rr["vb"]) < 1.5:
			continue
		var v: Dictionary = FootTrajectory.dribble_verdict(rr, rr["meta"])
		if bool(v["ok"]):
			dribble_ok.append(id)
		verdicts.append("- `%s` (%.2f m/s): %s" % [id, float(rr["vb"]), "**sirve**" if v["ok"] else "no sirve: " + "; ".join(v["reasons"])])
	verdicts.sort()
	note("clips de marcha que cumplen los criterios de conduccion con toques integrados: %s" % (str(dribble_ok) if not dribble_ok.is_empty() else "ninguno"))
	var cand: String = OS.get_environment("DRIBBLE_CANDIDATE")
	if cand != "":
		check(results.has(cand), "el clip candidato %s existe en las librerias" % cand)
		if results.has(cand):
			var cv: Dictionary = FootTrajectory.dribble_verdict(results[cand], results[cand]["meta"])
			check(bool(cv["ok"]), "el candidato %s cumple los criterios de conduccion (%s)" % [cand, "; ".join(cv["reasons"])])
	var out_path: String = OS.get_environment("INVENTORY_OUT")
	if out_path != "":
		var lines: Array[String] = []
		lines.append("# Inventario medido de animaciones (generado por `tests/test_animation_inventory.gd`)")
		lines.append("")
		lines.append("Cada fila es una animación convertida (`assets/animations/pack_clips.res` / `pack_keeper.res`, 133 FBX de origen +")
		lines.append("38 espejos `_mirror`). Medido sobre el esqueleto del futbolista a 60 Hz con `FootTrajectory`; posiciones en metros de")
		lines.append("juego respecto al jugador. **Empuje** = punta del pie a menos de %.2f m del suelo, más de %.2f m por delante del" % [FootTrajectory.LOW_TOE, FootTrajectory.AHEAD])
		lines.append("cuerpo y avanzando sobre el suelo %.1f m/s más rápido que el cuerpo (puede impulsar la pelota hacia delante)." % FootTrajectory.PUSH_MARGIN)
		lines.append("")
		lines.append("## Marchas y clips con pelota (detalle de empujes)")
		lines.append("")
		lines.append_array(detail)
		lines.append("")
		lines.append("## ¿Hay conducción en carrera con toques integrados? (criterios de `FootTrajectory.dribble_verdict`)")
		lines.append("")
		lines.append("Un toque de conducción lleva la punta del pie a ≥ %.2f m por delante del cuerpo, a ≤ %.2f m del suelo y %.1f m/s más" % [FootTrajectory.TOUCH_MIN_REACH, FootTrajectory.TOUCH_MAX_TOE, FootTrajectory.TOUCH_MIN_PUSH])
		lines.append("rápida que el cuerpo (más allá de una zancada: 0.16–0.28 m al trote, 0.27–0.39 m a sprint), un toque cada %.2f–%.2f s y" % [FootTrajectory.TOUCH_PERIOD_MIN, FootTrajectory.TOUCH_PERIOD_MAX])
		lines.append("como mucho %.2f m al costado. Clips de marcha en bucle que cumplen: **%s**." % [FootTrajectory.TOUCH_MAX_LATERAL, ", ".join(dribble_ok) if not dribble_ok.is_empty() else "ninguno"])
		lines.append("")
		lines.append_array(verdicts)
		lines.append("")
		lines.append("## Todas las animaciones")
		lines.append("")
		lines.append("| Animación | FBX de origen | Rol | Dur. (s) | Bucle | Raíz (m) | Cuerpo (m/s) | Pistas enlazadas | Empujes izq./der. | Alcance bajo izq./der. (m) | Altura mín. punta izq./der. (m) | En el código |")
		lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
		lines.append_array(rows)
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
		note("informe escrito en %s" % out_path)
