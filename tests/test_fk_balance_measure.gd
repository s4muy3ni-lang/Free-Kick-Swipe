extends TestCase
## MEDICION (no es una prueba de la suite): balance del arquero del tiro libre con un conjunto FIJO de 18 tiros (centro
## fuerte y debil, los dos angulos, rasantes, altos, con efecto hacia adentro y hacia afuera, cerca del poste, fuera de su
## alcance) desde cuatro puntos, con barrera y semillas fijas, en una o varias dificultades. Registra goles, atajadas,
## palos, afuera, barrera, si se tiro, cuanto antes de la llegada de la pelota arranco la estirada, si su plan llegaba y
## si se tiro a una pelota que no alcanzaba. Solo corre si se pide (con render, ~5 min por dificultad):
##   xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/run_tests.tscn \
##     -- --filter test_fk_balance_measure medir difs=0,1,2
## Resultados y decisiones en docs/AAA_ROADMAP.md.

## [etiqueta, punto de la pelota (desde el arco), altura, z, potencia, curva]
const SHOTS := [
	["centro fuerte", Vector3(-22, 0, 0), 1.2, 0.4, 0.95, 0.0], ["centro debil", Vector3(-22, 0, 0), 1.0, -0.3, 0.55, 0.0],
	["angulo sup. izq.", Vector3(-22, 0, 0), 2.1, -3.1, 0.8, -0.12], ["angulo sup. der.", Vector3(-22, 0, 0), 2.1, 3.1, 0.8, 0.12],
	["rasante izq.", Vector3(-22, 0, 0), 0.3, -2.8, 0.9, 0.0], ["rasante der.", Vector3(-22, 0, 0), 0.3, 2.8, 0.9, 0.0],
	["alto centro", Vector3(-22, 0, 0), 2.2, 0.8, 0.85, 0.0], ["efecto palo lejano", Vector3(-24, 0, -9), 1.6, 2.9, 0.75, 0.16],
	["cerca del poste", Vector3(-24, 0, -9), 1.0, -3.4, 0.9, 0.0], ["debil colocado", Vector3(-24, 0, -9), 0.8, 1.5, 0.5, 0.0],
	["fuerte al cuerpo", Vector3(-24, 0, -9), 1.3, -0.5, 1.0, 0.0], ["efecto hacia afuera", Vector3(-27, 0, 7), 1.8, -2.9, 0.85, -0.15],
	["rasante palo lejano", Vector3(-27, 0, 7), 0.4, -3.2, 1.0, 0.0], ["alto lejano", Vector3(-27, 0, 7), 2.0, 3.0, 0.8, 0.1],
	["centro medio", Vector3(-27, 0, 7), 1.4, 0.0, 0.7, 0.0], ["fuera de alcance bajo", Vector3(-18.5, 0, -4), 0.5, 3.3, 1.0, 0.0],
	["fuera de alcance alto", Vector3(-18.5, 0, -4), 2.2, 3.2, 0.65, 0.1], ["al cuerpo debil", Vector3(-18.5, 0, -4), 1.0, 0.3, 0.5, 0.0]]

func test_fk_balance() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("medir"):
		skip("medicion a pedido (argumento «medir», con render)")
		return
	var difs: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("difs="):
			for x in a.substr(5).split(","):
				difs.append(int(x))
	if difs.is_empty():
		difs = [1]
	for dif in difs:
		SpSettings.override_difficulty = dif
		var tally := {}
		var leads: Array = []
		var lines: PackedStringArray = []
		for i in SHOTS.size():
			var c: Array = SHOTS[i]
			SetPieceGame.next_mode = SetPieceGame.Mode.FREE_KICK
			var game: SetPieceGame = (load(SetPieceGame.SCENE) as PackedScene).instantiate()
			game.fast = true
			spawn(game)
			await physics_frames(5)
			SpSettings.override_difficulty = dif
			game.rng.seed = 700 + i
			game.cpu_keeper.rng.seed = 300 + i
			game.wall.rng.seed = 50 + i
			game.field.rng.seed = 90 + i
			game.ball_spot = game.clamp_free_kick_spot(Vector3(game.gx, 0, 0) + c[1])
			game._setup_free_kick()
			await physics_frames(10)
			game.shoot(Vector3(game.gx, c[2], c[3]), c[4], c[5])
			var k: SpKeeper = game.cpu_keeper
			var min_hand: float = INF
			var n: int = 0
			var dive_f: int = -1
			var cross_f: int = -1
			var touch_f: int = -1
			var plan_ok: bool = false
			while game.phase in [SetPieceGame.Phase.RUNUP, SetPieceGame.Phase.FLIGHT] and n < 900:
				await tree.physics_frame
				n += 1
				if game.phase != SetPieceGame.Phase.FLIGHT:
					continue
				var bp: Vector3 = game.ball.global_position
				if k.state == SpKeeper.State.DIVE and dive_f < 0:
					dive_f = n
					plan_ok = float(k.plan.get("dist", 9.0)) <= float(k.plan.get("radius", 0.0))
				for h in ["mixamorig_LeftHand", "mixamorig_RightHand"]:
					min_hand = minf(min_hand, k.actor.bone_world(h).distance_to(bp))
				if cross_f < 0 and bp.x >= k.actor.global_position.x - 0.3:
					cross_f = n
				if touch_f < 0 and k.touch_kind != &"":
					touch_f = n
			var res: String = game.outcome
			check(res != "", "%s: el tiro tiene resultado" % c[0])
			tally[res] = int(tally.get(res, 0)) + 1
			# Llegada de la pelota: cuando cruza al arquero o cuando la toca (una atajada no cruza).
			var arrive_f: int = cross_f if touch_f < 0 else (touch_f if cross_f < 0 else mini(cross_f, touch_f))
			var lead: float = float(arrive_f - dive_f) / 60.0 if dive_f >= 0 and arrive_f >= 0 else -1.0
			if dive_f >= 0:
				tally["estiradas"] = int(tally.get("estiradas", 0)) + 1
				if lead >= 0.0:
					leads.append(lead)
				if not plan_ok:
					tally["se tiro sin llegar"] = int(tally.get("se tiro sin llegar", 0)) + 1
			if k.touch_kind != &"":
				tally["toques"] = int(tally.get("toques", 0)) + 1
			lines.append("  %2d %-22s: %-5s toque «%s» se tiro %s, arranco %.2f s antes de la llegada, plan llega %s, mano-pelota %.2f m" % [
				i + 1, c[0], res, k.touch_kind, str(dive_f >= 0), lead, str(plan_ok), min_hand])
			cleanup()
		var avg_lead: float = 0.0
		for l in leads:
			avg_lead += float(l)
		avg_lead /= maxf(float(leads.size()), 1.0)
		note("dificultad %s: %s · la estirada arranca en promedio %.2f s antes de la llegada" % [SpSettings.ALL_DIFFICULTY_NAMES[dif], str(tally), avg_lead])
		for l in lines:
			note(l)
	SpSettings.override_difficulty = -1
