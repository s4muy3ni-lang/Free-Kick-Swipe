extends TestCase
## El catalogo completo se consulta sin perder tramos ni alterar el registro compartido.

func test_complete_catalog_is_defensive_and_includes_every_source() -> void:
	var bank: Dictionary = AnimDB.catalog()
	check(bank.size() == 2022, "2022 fuentes registradas")
	var segments: int = 0
	for entry in bank.values():
		segments += entry.get("tramos", []).size()
	check(segments == 2024, "2024 tramos conservados")
	bank.clear()
	check(AnimDB.catalog().size() == 2022, "el consumidor no puede borrar el indice central")
	var r: Dictionary = AnimDB.record(&"jn_gk_dive_0000_mirror")
	check(r.get("nombre", "") == "GKSAVE_ET0103_XF0250_DIVELOWRIGHT", "espejo resuelve fuente original")
	r.clear()
	check(not AnimDB.record(&"0000").is_empty(), "registro tambien protegido")
	check(AnimDB.record(&"no_existe").is_empty(), "id desconocido sin sustitucion arbitraria")

func test_context_filters_preserve_role_and_mirror_coverage() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	var all: Array[StringName] = AnimDB.candidates(&"celebrate")
	check(not all.is_empty(), "resuelve por accion")
	check(all == PackLibrary.by_role(&"celebrate"), "sin filtros no descarta variantes")
	var filtered: Array[StringName] = AnimDB.candidates(&"celebrate", {"mirrors": false, "max_root": 1.0, "min_duration": 0.6})
	for id in filtered:
		check(not String(id).ends_with("_mirror"), "%s sin espejo solicitado" % id)
		check((PackLibrary.meta(id).get("root_total", Vector2.ZERO) as Vector2).length() <= 1.0, "%s cabe en el espacio solicitado" % id)
	check(AnimDB.candidates(&"accion_inexistente").is_empty(), "accion desconocida no reproduce otra")
	var selected: StringName = JsonCatalog.situation_clip(&"celebrate", 3)
	check(filtered.has(selected) or AnimDB.candidates(&"clap", {"mirrors": false, "max_root": 1.0, "min_duration": 0.6}).has(selected), "partido utiliza el resolver central")
