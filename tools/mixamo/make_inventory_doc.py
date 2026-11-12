#!/usr/bin/env python3
"""Genera docs/animaciones/INVENTARIO_MIXAMO.md con los datos MEDIDOS de la conversion de Mixamo.

Entradas (no versionadas, salen de las herramientas):
  --sel      tools/mixamo/selection_mixamo.json (versionado)
  --index    <MIXAMO_JSON>/index.json            (export_mixamo_joints: duracion, recorrido, apoyo)
  --build    <OUT>/build.log                     (build_json_library: lineas CLIP con contacto y suelo)
  --actual   inventario ACTUAL por rol           (dump_inventory.tscn con INV_BANK=actual)
  --mixamo   inventario MIXAMO por rol           (dump_inventory.tscn con INV_BANK=mixamo)
  --out      docs/animaciones/INVENTARIO_MIXAMO.md
"""
import argparse
import json
import re

# Sistemas del juego que piden cada rol (verificado con grep en scripts/; ver MIXAMO_INTEGRACION.md, seccion 5).
CONSUMERS = {
    "setpiece_shot": "Penales y tiros libres (ShotCatalog)", "setpiece_lob": "Penales y tiros libres (ShotCatalog, vaselina)",
    "setpiece_pass": "Penales y tiros libres (ShotCatalog, colocado)", "kick_shot": "ShotCatalog; menu (fondo)",
    "kick_shot_hard": "ShotCatalog (potente)", "kick_pass": "ShotCatalog (colocado)", "volley": "Modo partido (BallHandler)",
    "idle_ready": "Tirador, compañeros, menu, minijuegos (Guante)", "jog": "Tirador (carrera), festejos, jugadores sueltos",
    "run": "Festejos (carrera), tirador (MIXAMO)", "sprint": "Tirador (MIXAMO, carrera rapida)",
    "loco_sprint": "Festejos (carrera)", "walk": "Tirador (camina a la pelota)",
    "dir_back": "Tiro libre: defensores que retroceden", "dir_back_diag": "Tiro libre: defensores (diagonal atras)",
    "dir_fwd_diag": "Tiro libre: defensores (diagonal)", "dir_side": "Tiro libre: defensores (de costado)",
    "start": "Modo partido (arranques)", "turn_run": "Modo partido (giros)", "defend": "Tiro libre: defensores llegan marcando",
    "header": "Tiro libre: despeje de cabeza del defensor", "fall": "Boton de caida; modo partido",
    "fall_hit": "Modo partido (caidas por choque)", "trip": "Modo partido (zancadilla)", "slide": "Modo partido (barrida)",
    "stumble": "Boton de caida; modo partido", "stumble_light": "Modo partido", "lie": "Arquero (en el suelo); modo partido",
    "getup": "Boton de caida; modo partido", "ball_dribble": "Modo partido (conduccion)", "ball_turn": "Modo partido (giro con pelota)",
    "ball_skill": "Modo partido (amagues)", "receive_chest": "Modo partido (recepcion de pecho)",
    "receive_foot": "Modo partido (recepcion)", "throw_in": "Modo partido (lateral)", "shove": "Modo partido (empujon)",
    "angry": "Reacciones (tirador que erra, arquero vencido)", "dejected": "Reacciones (lamento)",
    "defeat_end": "Modo partido (final perdido)", "celebrate": "Reacciones (gol, arquero que ataja)",
    "celebrate_scorer": "Festejo del goleador", "celebrate_team": "Festejo de los compañeros", "clap": "Reacciones (aplauso)",
    "thumbs_up": "Reacciones (defensor contento)", "jump": "Modo partido (salto)", "warmup": "Modo partido (previa)",
    "referee": "Laboratorio (sin situacion en el juego)", "gk_idle": "Arquero (espera), menu",
    "gk_idle_ball": "Modo partido (arquero con la pelota)", "gk_sidestep": "Arquero: planificador de atajadas",
    "gk_dive": "Arquero: planificador de atajadas", "gk_catch": "Arquero: planificador (blocaje/recogida)",
    "gk_scoop": "Arquero: planificador (recogida)", "gk_block": "Arquero: planificador (achique)",
    "gk_miss": "Modo partido (arquero vencido)", "gk_throw": "Modo partido (saque con la mano)",
    "gk_roll": "Modo partido (saque rodando)", "gk_kick": "Modo partido (saque de volea)",
    "gk_place": "Modo partido (saque de piso)", "gk_direct": "Modo partido (saque directo)",
}

def main() -> None:
    ap = argparse.ArgumentParser()
    for k in ["sel", "index", "build", "actual", "mixamo", "out"]:
        ap.add_argument("--" + k, required=True)
    a = ap.parse_args()
    sel = json.load(open(a.sel))["clips"]
    index = {e["source"]: e for e in json.load(open(a.index))}
    act = json.load(open(a.actual))
    mx = json.load(open(a.mixamo))
    clip_line = {}
    for line in open(a.build, encoding="utf-8", errors="replace"):
        m = re.match(r"CLIP (\S+)\s+([\d.]+)s (\S+) (\S+)\s+nat=([\d.]+) suelo=([+-][\d.]+) cm raiz=\(([-\d.]+),([-\d.]+)\)(.*)", line)
        if m:
            clip_line[m.group(1)] = m
    out = []
    w = out.append
    w("# Inventario MIXAMO y correspondencias con ACTUAL (generado)")
    w("")
    w("Generado por `tools/mixamo/make_inventory_doc.py` con los datos medidos por `export_mixamo_joints`, ")
    w("`build_json_library` y `dump_inventory` (2026-11-12). Fuente: `animaciones_mixamo.zip` (`mixamo_campo.glb` 110 clips, ")
    w("`mixamo_arquero.glb` 23). Explicacion de cada columna y decisiones: [`MIXAMO_INTEGRACION.md`](MIXAMO_INTEGRACION.md).")
    w("")
    w(f"- ACTUAL: **{act['clips']} clips** ({act['with_mirrors']} con espejos) en {len(act['roles'])} roles.")
    w(f"- MIXAMO: **{mx['clips']} clips** ({mx['with_mirrors']} con espejos) en {len(mx['roles'])} roles.")
    w("")
    w("## 1. Clips de Mixamo (los 133)")
    w("")
    w("Suelo = altura del tobillo apoyado respecto del esqueleto del juego (percentil 10; 0 = apoyado, - hundido, + en el aire). ")
    w("Raiz = desplazamiento total reconstruido (adelante, derecha) en m. Apoyo = fraccion de cuadros con un pie apoyado. ")
    w("Contacto = instante y pie del golpe medido sobre el cuerpo del juego.")
    w("")
    w("| # | Clip original | GLB | Id | Rol | Biblioteca | Dur. (s) | Bucle | Suelo (cm) | Raiz (m) | Apoyo | Contacto | Espejo |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for i, e in enumerate(sel):
        ix = index.get(e["source"], {})
        cl = clip_line.get(e["id"])
        cont = "-"
        if cl and "contacto" in cl.group(9):
            mm = re.search(r"contacto t=([\d.]+)s pie=(\S)", cl.group(9))
            if mm:
                cont = f"{mm.group(1)} s, {mm.group(2)}"
        raiz = f"({float(cl.group(7)):.2f}, {float(cl.group(8)):.2f})" if cl else "-"
        w(f"| {i} | {e['source']} | {ix.get('glb', '-')} | `{e['id']}` | {e['role']} | {e.get('library', 'field')} | "
          f"{float(ix.get('length', 0.0)):.2f} | {'si' if cl and cl.group(3) == 'bucle' else 'no'} | "
          f"{cl.group(6) if cl else '-'} | {raiz} | {float(ix.get('support_ratio', 0.0)):.2f} | {cont} | "
          f"{'si' if e.get('mirror') else 'no'} |")
    w("")
    w("## 2. Correspondencias por rol (Mixamo -> rol del juego -> sistemas)")
    w("")
    w("Con la biblioteca MIXAMO, cada rol de esta tabla usa SOLO los clips de Mixamo. La equivalencia se decidio mirando ")
    w("cada clip (movimiento, raiz, contacto), no por el nombre; ver la justificacion por grupo en MIXAMO_INTEGRACION.md.")
    w("")
    w("| Rol | Clips Mixamo | Clips ACTUAL del rol | Quien lo usa en el juego |")
    w("|---|---|---|---|")
    for role in sorted(mx["roles"]):
        ids = [e["source"] for e in sel if e["role"] == role]
        w(f"| {role} | {mx['roles'][role]['clips']}: {', '.join(ids)} | {act['roles'].get(role, {}).get('clips', 0)} | "
          f"{CONSUMERS.get(role, '-')} |")
    w("")
    w("## 3. Roles ACTUALES sin equivalente en Mixamo (siguen con el actual: respaldo)")
    w("")
    w("| Rol | Clips ACTUAL |")
    w("|---|---|")
    for role in sorted(r for r in act["roles"] if r not in mx["roles"]):
        w(f"| {role or '(sin rol)'} | {act['roles'][role]['clips']} |")
    w("")
    open(a.out, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("escrito", a.out)

if __name__ == "__main__":
    main()
