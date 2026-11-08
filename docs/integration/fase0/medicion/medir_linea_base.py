#!/usr/bin/env python3
"""Medicion reproducible de la linea base del sistema de animaciones (Fase 0 de la guia maestra).

No modifica el repositorio: crea un `git worktree` del commit indicado en un directorio de trabajo externo, le aplica una
instrumentacion que SOLO REGISTRA (no cambia decisiones del juego), juega partidos IA contra IA con todas las semillas
fijadas y vuelca metricas comparables entre fases (JSON + CSV).

Uso tipico (desde la raiz del repositorio):
    python3 docs/integration/fase0/medicion/medir_linea_base.py --commit pre-audit-phase-0 \
        --work /tmp/medicion --out docs/integration/fase0/linea_base \
        --seeds 101,202,303,404,505,606 --minutes 10 --repeat-seed 101 --render-seed 707 --render-minutes 3 --jobs 3

Requisitos: Godot 4.7.2 en el PATH (o GODOT=/ruta), git; para --render-seed, xvfb-run y Mesa (OpenGL por software).

Instrumentacion aplicada en la copia (y solo alli):
  - FootballerVisual.play_pack_clip: cuenta cada clip disparado (id resuelto en el modo 4).
  - FootballerVisual._setup_animation_tree: clips de los espacios de mezcla (marcha, conduccion, direccional).
  - BallHandler._log_kick / _finish_clip_kick: cada golpeo (resultado, distancia pelota-punto de contacto del clip, clip,
    esqueleto vivo, equipo, posicion y velocidad de salida de la pelota).
  - BallHandler.dispose: acumula kick_stats, JsonReceive.stats y JsonBallMove.stats de cada futbolista liberado.
  - Escena zz_match_run.tscn: partido con IA en los 10 jugadores; siembra AIInput, BallHandler, PlayerActions, Goalkeeper,
    MatchPresentation y PackLibrary._vary_rng desde la semilla; mide perdidas tras recepcion animada (FIRST_TOUCH
    planned), goles en propia y estadisticas del arbitro y de los arqueros.
"""
import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor

GODOT = os.environ.get("GODOT", "godot")

# --- Parches (texto exacto del codigo auditado; si no coincide, la medicion se detiene) --------------------------------

PATCHES = [
    ("scripts/player/footballer_visual.gd",
     "signal action_finished(clip: StringName)\n",
     "signal action_finished(clip: StringName)\nstatic var audit_plays: Dictionary = {}\nstatic var audit_tree: Dictionary = {}\n"),
    ("scripts/player/footballer_visual.gd",
     "\tcurrent_action = id\n\t_action_timer = (anim.length - from) / maxf(speed, 0.05)",
     "\tcurrent_action = id\n\tvar _rid: String = String(PackLibrary.resolve(id)) if json_mode else String(id)\n"
     "\taudit_plays[_rid] = int(audit_plays.get(_rid, 0)) + 1\n\t_action_timer = (anim.length - from) / maxf(speed, 0.05)"),
    ("scripts/player/footballer_visual.gd",
     "\ttree_root.connect_node(&\"output\", 0, previous)",
     "\tif json_mode:\n\t\tfor pt in JsonCatalog.gait_points(false): audit_tree[String(pt[0])] = \"gait\"\n"
     "\t\tfor pt in JsonCatalog.gait_points(true): audit_tree[String(pt[0])] = \"carry\"\n"
     "\t\tfor pt in JsonCatalog.dir_points(keeper_mode): audit_tree[String(pt[0])] = \"dir\"\n"
     "\ttree_root.connect_node(&\"output\", 0, previous)"),
    ("scripts/player/ball_handler.gd",
     "func _init(o: Footballer) -> void:",
     "static var audit_kicks: Dictionary = {}\nstatic var audit_receive: Dictionary = {}\nstatic var audit_move: Dictionary = {}\n"
     "static var audit_kick_log: Array = []\n\nfunc _init(o: Footballer) -> void:"),
    ("scripts/player/ball_handler.gd",
     "func dispose() -> void:\n",
     "func dispose() -> void:\n"
     "\tfor k in kick_stats: audit_kicks[k] = int(audit_kicks.get(k, 0)) + int(kick_stats[k])\n"
     "\tif receive != null:\n\t\tfor k in receive.stats: audit_receive[k] = int(audit_receive.get(k, 0)) + int(receive.stats[k])\n"
     "\tif json_move != null:\n\t\tfor k in json_move.stats: audit_move[k] = int(audit_move.get(k, 0)) + int(json_move.stats[k])\n"),
    ("scripts/player/ball_handler.gd",
     "\tentry.merge(extra)\n\tkick_log.append(entry)",
     "\tentry.merge(extra)\n\tkick_log.append(entry)\n"
     "\tvar _ab: Ball = ball()\n"
     "\taudit_kick_log.append({\"r\": String(result), \"a\": String(action), \"d\": float(entry.get(\"foot_distance\", -1.0)), "
     "\"c\": String(entry.get(\"clip\", \"\")), \"live\": feet_live, \"team\": owner.team, \"t\": owner.ctx.match_time if owner.ctx != null else 0.0, "
     "\"bx\": _ab.global_position.x if _ab != null else 0.0, \"by\": _ab.global_position.y if _ab != null else 0.0, "
     "\"px\": owner.global_position.x, \"pz\": owner.global_position.z, \"bz\": _ab.global_position.z if _ab != null else 0.0, "
     "\"pred\": float(entry.get(\"predicted\", -1.0)), \"lat\": float(entry.get(\"latency\", -1.0)), \"adj\": float(entry.get(\"adjust_m\", -1.0)), "
     "\"bv0\": float(entry.get(\"ball_v0\", -1.0)), \"pv0\": float(entry.get(\"body_v0\", -1.0)), \"intf\": bool(entry.get(\"interfered\", false)), "
     "\"turn\": bool(entry.get(\"turn\", false)), \"aer\": String(entry.get(\"aerial\", \"\")), "
     "\"ex\": entry.get(\"exec\", {})})"),
    ("scripts/player/ball_handler.gd",
     "\tvar res: KickModel.KickResult = perform_action(action, _kick_stick, _kick_charge, _kick_lob)\n\t_kick_event_info = {}",
     "\tvar res: KickModel.KickResult = perform_action(action, _kick_stick, _kick_charge, _kick_lob)\n"
     "\tif res != null and not audit_kick_log.is_empty():\n"
     "\t\taudit_kick_log[-1][\"vx\"] = res.velocity.x\n\t\taudit_kick_log[-1][\"vy\"] = res.velocity.y\n\t\taudit_kick_log[-1][\"vz\"] = res.velocity.z\n"
     "\t_kick_event_info = {}"),
]

DUMP_GD = '''class_name AuditDump
extends RefCounted
static func data() -> Dictionary:
	return {"plays": FootballerVisual.audit_plays, "tree": FootballerVisual.audit_tree, "kicks": BallHandler.audit_kicks,
		"receive": BallHandler.audit_receive, "move": BallHandler.audit_move, "kick_log": BallHandler.audit_kick_log}
'''

RUNNER_GD = '''extends Node
## Medicion (copia aislada): partido IA contra IA con todas las semillas fijadas.
var _pending: Array = []
var _recv := {"planned_touches": 0, "kept": 0, "lost": 0, "physical_touches": 0}
var _goals := {"total": 0, "own": 0}
var _m: MatchScene = null

func _ready() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	var minutes: float = float(OS.get_environment("MATCH_MIN"))
	var seed: int = int(OS.get_environment("MATCH_SEED"))
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	_m = m
	m.duration_seconds = minutes * 60.0
	m.intro_seconds = 0.0
	m.auto_switch = false
	add_child(m)
	for i in 3:
		await get_tree().physics_frame
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	m.controlled = null
	# vary_aliases() re-aleatoriza su RNG en la primera llamada: se llama una vez y luego se siembra.
	PackLibrary.vary_aliases()
	PackLibrary._vary_rng.seed = seed * 7 + 1
	for f in m.home + m.away:
		if f.input_source is AIInput:
			(f.input_source as AIInput).rng.seed = seed + f.actor_id * 17
		f.ball_handler.rng.seed = seed * 31 + f.actor_id
		f.actions.rng.seed = seed * 37 + f.actor_id
	for k in m.ctx.keepers:
		k.rng.seed = seed * 41 + int(k.actor_id)
	if m.presentation != null:
		m.presentation.rng.seed = seed * 43
	var counts := {}
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void:
		counts[e.type_name()] = int(counts.get(e.type_name(), 0)) + 1
		var sp: SetPiece = m.manager.active_set_piece
		if sp != null and not sp.has_meta(&"seeded"):
			sp.rng.seed = seed * 47 + int(m.ctx.match_time * 10.0)
			sp.set_meta(&"seeded", true)
		if e.type == GameEvent.Type.FIRST_TOUCH and not e.data.get("keeper", false):
			if e.data.get("planned", false):
				_recv["planned_touches"] += 1
				_pending.append([m.ctx.match_time, e.team])
			else:
				_recv["physical_touches"] += 1
		elif e.type == GameEvent.Type.GOAL:
			_goals["total"] += 1
			if e.data.get("own_goal", false):
				_goals["own"] += 1)
	var frames: int = int(minutes * 60.0 * 60.0 * 3.0)
	for i in frames:
		await get_tree().physics_frame
		_check_pending()
		if m.manager.state == MatchManager.State.FULL_TIME:
			break
	var keeper_stats := []
	for k in m.ctx.keepers:
		keeper_stats.append(k.stats.duplicate())
	var arb := {}
	for f in m.home + m.away:
		for k in f.arbiter.stats:
			arb[k] = int(arb.get(k, 0)) + int(f.arbiter.stats[k])
	var extra := {"seed": seed, "minutes": minutes, "score": m.manager.score, "clock": m.ctx.match_time, "events": counts,
		"keepers": keeper_stats, "arbiter": arb, "reception_outcome": _recv, "goals": _goals,
		"presentation": m.presentation.invocations if m.presentation != null else {}}
	m.queue_free()
	for i in 5:
		await get_tree().physics_frame
	var out: Dictionary = AuditDump.data()
	out.merge(extra)
	var f2 := FileAccess.open(OS.get_environment("MEASURE_OUT"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(out))
	f2.close()
	get_tree().quit()

## Recepcion animada: el equipo conserva la pelota 2 s despues del toque (poseedor arbitrado del mismo equipo, o pelota
## tocada por ultima vez por su equipo sin poseedor).
func _check_pending() -> void:
	var now: float = _m.ctx.match_time
	while not _pending.is_empty() and now - float(_pending[0][0]) >= 2.0:
		var p: Array = _pending.pop_front()
		_m.ctx.update_possession()
		var team_now: int = _m.ctx.possessor.team if _m.ctx.possessor != null else int(_m.ball.last_touch_team)
		if team_now == int(p[1]):
			_recv["kept"] += 1
		else:
			_recv["lost"] += 1
'''

SCENE_TSCN = '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://zz_match_run.gd" id="1"]\n\n[node name="Run" type="Node"]\nscript = ExtResource("1")\n'

META_GD = '''extends Node
func _ready() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	var out := {}
	for lib in [PackLibrary.field(), PackLibrary.keeper()]:
		for id in lib.get_animation_list():
			var m: Dictionary = lib.get_animation(id).get_meta("pack", {})
			out[String(id)] = {"role": String(m.get("role", "")), "contact": m.has("contact")}
	var f := FileAccess.open(OS.get_environment("MEASURE_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	get_tree().quit()
'''


def sh(cmd, cwd=None, env=None, check=True):
    r = subprocess.run(cmd, cwd=cwd, env=env, shell=isinstance(cmd, str), capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"fallo: {cmd}\n{r.stdout[-2000:]}\n{r.stderr[-2000:]}")
    return r


def prepare(repo, commit, work):
    wt = os.path.join(work, "copia_medicion")
    if os.path.exists(wt):
        sh(["git", "worktree", "remove", "--force", wt], cwd=repo, check=False)
        shutil.rmtree(wt, ignore_errors=True)
    os.makedirs(work, exist_ok=True)
    sh(["git", "worktree", "add", "--detach", "-f", wt, commit], cwd=repo)
    head = sh(["git", "rev-parse", "HEAD"], cwd=wt).stdout.strip()
    for path, old, new in PATCHES:
        p = os.path.join(wt, path)
        s = open(p).read()
        if s.count(old) != 1:
            sys.exit(f"el parche no coincide con {path}: el codigo cambio; actualizar medir_linea_base.py")
        open(p, "w").write(s.replace(old, new, 1))
    open(os.path.join(wt, "zz_audit_dump.gd"), "w").write(DUMP_GD)
    open(os.path.join(wt, "zz_match_run.gd"), "w").write(RUNNER_GD)
    open(os.path.join(wt, "zz_match_run.tscn"), "w").write(SCENE_TSCN)
    open(os.path.join(wt, "zz_meta.gd"), "w").write(META_GD)
    open(os.path.join(wt, "zz_meta.tscn"), "w").write(SCENE_TSCN.replace("zz_match_run.gd", "zz_meta.gd"))
    r = sh([GODOT, "--headless", "--path", ".", "--import"], cwd=wt, check=False)
    if "SCRIPT ERROR" in r.stdout + r.stderr or "Parse Error" in r.stdout + r.stderr:
        sys.exit("la copia instrumentada no compila:\n" + (r.stdout + r.stderr)[-3000:])
    return wt, head


def run_match(wt, out_dir, seed, minutes, render, tag):
    out = os.path.join(out_dir, f"partido_{tag}.json")
    env = dict(os.environ, MATCH_MIN=str(minutes), MATCH_SEED=str(seed), MEASURE_OUT=out)
    cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", ".", "res://zz_match_run.tscn"]
    if render:
        cmd = ["xvfb-run", "-a", GODOT, "--display-driver", "x11", "--rendering-driver", "opengl3", "--fixed-fps", "60",
               "--path", ".", "res://zz_match_run.tscn"]
    r = subprocess.run(cmd, cwd=wt, env=env, capture_output=True, text=True, timeout=7200)
    log = r.stdout + r.stderr
    errors = [l for l in log.splitlines() if "SCRIPT ERROR" in l]
    with open(os.path.join(out_dir, f"partido_{tag}.log"), "w") as f:
        f.write("\n".join(l for l in log.splitlines() if "ERROR" in l or "WARNING" in l))
    if not os.path.exists(out):
        sys.exit(f"el partido {tag} no produjo datos (rc={r.returncode})")
    return tag, out, errors


def pct(n, d):
    return round(100.0 * n / d, 2) if d else None


def quant(xs, q):
    if not xs:
        return None
    s = sorted(xs)
    return round(s[min(len(s) - 1, int(q * len(s)))], 4)


def match_metrics(d, meta):
    J = set(meta)
    base = lambda i: i[:-7] if i.endswith("_mirror") else i
    played = (set(d["plays"]) | set(d["tree"])) & J
    kl = d["kick_log"]
    ok = [e for e in kl if e["r"] == "contact" and e["d"] >= 0]
    role = lambda c: meta.get(c, {}).get("role", "")
    aerial = [e for e in kl if role(e["c"]) in ("header", "volley")]
    aerial_ok = [e for e in aerial if e["r"] == "contact"]
    ground = [e for e in kl if role(e["c"]) not in ("header", "volley") and e["r"] in ("contact", "missed")]
    # Golpeo hacia el propio arco: el equipo 0 ataca +X; pelota que sale con componente hacia su propio arco y a mas de
    # 8 m/s, golpeada en su mitad defensiva.
    toward_own = 0
    for e in ok:
        if "vx" not in e:
            continue
        atk = 1.0 if e["team"] == 0 else -1.0
        if e["vx"] * atk < -8.0 and e["bx"] * atk < 0.0:
            toward_own += 1
    plays = Counter(d["plays"])
    jplays = {k: v for k, v in plays.items() if k in J}
    total_plays = sum(jplays.values())
    top = plays.most_common(1)[0] if plays else ("", 0)
    mv = d["move"]
    rc = d["receive"]
    ro = d["reception_outcome"]
    arb = d["arbiter"]
    k = d["kicks"]
    return {
        "semilla": d["seed"], "minutos": d["minutes"], "reloj": round(d["clock"], 1), "marcador": d["score"],
        "goles": d["goals"]["total"], "goles_en_propia": d["goals"]["own"],
        "pases": d["events"].get("PASS", 0), "tiros": d["events"].get("SHOT", 0), "golpeos_en_falso_evento": d["events"].get("KICK_WHIFF", 0),
        "tramos_reproducidos": len({base(i) for i in played}), "variantes_reproducidas": len(played),
        "roles_reproducidos": len({meta[i]["role"] for i in played}),
        "golpeos_iniciados": k.get("started", 0), "golpeos_contacto": k.get("contact", 0), "golpeos_fallidos": k.get("missed", 0),
        "golpeos_fuera_de_alcance": k.get("out_of_reach", 0), "golpeos_girando": k.get("turn", 0),
        "pct_golpeos_iniciados_sin_contacto": pct(k.get("started", 0) - k.get("contact", 0), k.get("started", 0)),
        "contacto_dist_mediana": quant([e["d"] for e in ok], 0.5), "contacto_dist_p90": quant([e["d"] for e in ok], 0.9),
        "contacto_dist_p95": quant([e["d"] for e in ok], 0.95),
        "contacto_dist_max": round(max([e["d"] for e in ok]), 4) if ok else None,
        "pct_contactos_hasta_020": pct(sum(e["d"] <= 0.20 for e in ok), len(ok)),
        "pct_contactos_hasta_030": pct(sum(e["d"] <= 0.30 for e in ok), len(ok)),
        "pct_contactos_mas_030": pct(sum(e["d"] > 0.30 for e in ok), len(ok)),
        "golpeos_aereos": len(aerial), "golpeos_aereos_contacto": len(aerial_ok),
        "pct_aereos_fallidos": pct(len(aerial) - len(aerial_ok), len(aerial)),
        "pct_rasos_fallidos": pct(sum(e["r"] == "missed" for e in ground), len(ground)),
        "golpeos_hacia_arco_propio": toward_own,
        "recepciones_clip_iniciadas": rc.get("started", 0), "recepciones_clip_contacto": rc.get("contact", 0),
        "recepciones_clip_abortadas": rc.get("aborted", 0), "recepciones_clip_fallidas": rc.get("missed", 0),
        "pct_recepciones_clip_abortadas": pct(rc.get("aborted", 0), rc.get("started", 0)),
        "primeros_toques_con_clip": ro["planned_touches"], "primeros_toques_fisicos": ro["physical_touches"],
        "pct_primeros_toques_con_clip": pct(ro["planned_touches"], ro["planned_touches"] + ro["physical_touches"]),
        "pct_perdida_tras_recepcion_animada": pct(ro["lost"], ro["kept"] + ro["lost"]),
        "mov_pelota_iniciados": mv.get("started", 0), "mov_pelota_cortados": mv.get("aborted", 0), "mov_pelota_toques_perdidos": mv.get("missed", 0),
        "pct_mov_pelota_cortados": pct(mv.get("aborted", 0), mv.get("started", 0)),
        "arbitro_aceptadas": arb.get("aceptadas", 0), "arbitro_rechazadas": arb.get("rechazadas", 0),
        "arbitro_interrumpidas": arb.get("interrumpidas", 0),
        "pct_arbitro_rechazadas": pct(arb.get("rechazadas", 0), arb.get("aceptadas", 0) + arb.get("rechazadas", 0)),
        "reproducciones_banco": total_plays, "clip_mas_repetido": top[0], "reproducciones_clip_mas_repetido": top[1],
        "pct_clip_mas_repetido": pct(top[1], total_plays),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--commit", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--seeds", default="101,202,303,404,505,606")
    ap.add_argument("--minutes", type=float, default=10.0)
    ap.add_argument("--repeat-seed", type=int, default=None)
    ap.add_argument("--render-seed", type=int, default=None)
    ap.add_argument("--render-minutes", type=float, default=3.0)
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--keep-meta", action="store_true", help="conservar _meta.json (metadatos de los clips) en --out")
    a = ap.parse_args()
    repo = sh(["git", "rev-parse", "--show-toplevel"]).stdout.strip()
    out_dir = os.path.abspath(a.out)
    os.makedirs(out_dir, exist_ok=True)
    wt, head = prepare(repo, a.commit, os.path.abspath(a.work))
    meta_path = os.path.join(out_dir, "_meta.json")
    sh([GODOT, "--headless", "--path", ".", "res://zz_meta.tscn"], cwd=wt, env=dict(os.environ, MEASURE_OUT=meta_path))
    meta = json.load(open(meta_path))
    jobs = [(int(s), a.minutes, False, f"s{s}") for s in a.seeds.split(",") if s]
    if a.repeat_seed is not None:
        jobs.append((a.repeat_seed, a.minutes, False, f"s{a.repeat_seed}_repeticion"))
    if a.render_seed is not None:
        jobs.append((a.render_seed, a.render_minutes, True, f"s{a.render_seed}_render"))
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        results = list(ex.map(lambda j: run_match(wt, out_dir, j[0], j[1], j[2], j[3]), jobs))
    write_summary(out_dir, results, meta, head, a.repeat_seed)
    if not a.keep_meta:
        os.remove(meta_path)
    sh(["git", "worktree", "remove", "--force", wt], cwd=repo, check=False)


def recalc():
    """Recalcula metricas.json de un directorio ya medido (partido_*.json y .log) con las metricas actuales, sin jugar.
    Uso: medir_linea_base.py --recalcular DIR --meta _meta.json [--repeat-seed N]"""
    ap = argparse.ArgumentParser()
    ap.add_argument("--recalcular", required=True)
    ap.add_argument("--meta", required=True)
    ap.add_argument("--repeat-seed", type=int, default=None)
    a = ap.parse_args()
    out_dir = os.path.abspath(a.recalcular)
    meta = json.load(open(a.meta))
    prev = os.path.join(out_dir, "metricas.json")
    head = json.load(open(prev)).get("commit", "") if os.path.exists(prev) else ""
    tags = sorted(f[len("partido_"):-len(".json")] for f in os.listdir(out_dir) if f.startswith("partido_") and f.endswith(".json"))
    results = []
    for tag in tags:
        log = os.path.join(out_dir, f"partido_{tag}.log")
        errors = [l for l in open(log).read().splitlines() if "SCRIPT ERROR" in l] if os.path.exists(log) else []
        results.append((tag, os.path.join(out_dir, f"partido_{tag}.json"), errors))
    write_summary(out_dir, results, meta, head, a.repeat_seed)


def write_summary(out_dir, results, meta, head, repeat_seed):
    rows = []
    union_played = set()
    plays_total = Counter()
    for tag, path, errors in results:
        d = json.load(open(path))
        mm = match_metrics(d, meta)
        mm["partido"] = tag
        mm["script_errors"] = len(errors)
        rows.append(mm)
        if not tag.endswith("_repeticion"):
            union_played |= (set(d["plays"]) | set(d["tree"])) & set(meta)
            plays_total.update({k: v for k, v in d["plays"].items() if k in meta})
    base = lambda i: i[:-7] if i.endswith("_mirror") else i
    roles_all = {v["role"] for v in meta.values()}
    roles_seen = {meta[i]["role"] for i in union_played}
    summary = {
        "commit": head, "partidos": [r["partido"] for r in rows],
        "tramos_totales": len({base(i) for i in meta}), "variantes_totales": len(meta),
        "tramos_reproducidos_union": len({base(i) for i in union_played}), "variantes_reproducidas_union": len(union_played),
        "roles_reproducidos_union": len(roles_seen), "roles_totales": len(roles_all),
        "roles_nunca_reproducidos": sorted(roles_all - roles_seen),
    }
    det = None
    if repeat_seed is not None:
        r1 = next(r for r in rows if r["partido"] == f"s{repeat_seed}")
        r2 = next(r for r in rows if r["partido"] == f"s{repeat_seed}_repeticion")
        keys = [k for k in r1 if k not in ("partido",)]
        diff = {k: [r1[k], r2[k]] for k in keys if r1[k] != r2[k]}
        det = {"semilla": repeat_seed, "identico": not diff, "diferencias": diff}
    summary["determinismo"] = det
    agg_keys = [k for k in rows[0] if isinstance(rows[0][k], (int, float)) and k not in ("semilla", "minutos")]
    normal = [r for r in rows if not r["partido"].endswith("_repeticion")]
    summary["por_partido"] = rows
    summary["medias_por_partido"] = {k: round(statistics.mean([r[k] for r in normal if r[k] is not None]), 3)
                                     for k in agg_keys if any(r[k] is not None for r in normal)}
    json.dump(summary, open(os.path.join(out_dir, "metricas.json"), "w"), indent=1, ensure_ascii=False)
    cols = ["partido"] + [k for k in rows[0] if k != "partido"]
    with open(os.path.join(out_dir, "metricas_por_partido.csv"), "w") as f:
        f.write(",".join(cols) + "\n")
        for r in rows:
            f.write(",".join(json.dumps(r[c], ensure_ascii=False).replace(",", ";") for c in cols) + "\n")
    with open(os.path.join(out_dir, "reproducciones_por_clip.csv"), "w") as f:
        f.write("clip,rol,reproducciones\n")
        for c, n in plays_total.most_common():
            f.write(f"{c},{meta[c]['role']},{n}\n")
    print(json.dumps({k: v for k, v in summary.items() if k != "por_partido"}, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    recalc() if "--recalcular" in sys.argv else main()
