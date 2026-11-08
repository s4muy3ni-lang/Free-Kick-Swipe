#!/usr/bin/env python3
"""Genera docs/technical-index/ANIMATION_PACK_CLIPS.md (tabla de los 133 clips) a partir de:
  - <salida>/rows.json        (analyze_metrics.py, sobre la salida de pack_metrics.gd)
  - <salida>/fbx_times.json   (fbx_times.py: duracion leida del FBX en bruto)
  - pack/indice_futbol.json   (indice del pack: nombre, descripcion, duracion declarada)
  - tools/animation_pack/evaluation_notes.json   (curado a mano: recomendacion, ola, verificacion visual)
Uso: python3 tools/animation_pack/make_report.py <dir_salida> [pack/indice_futbol.json] [salida.md]
"""
import json, os, sys, datetime, collections

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
out_dir = sys.argv[1]
index_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "pack", "indice_futbol.json")
md_path = sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, "docs", "technical-index", "ANIMATION_PACK_CLIPS.md")
rows = json.load(open(os.path.join(out_dir, "rows.json")))
k_game = rows["K_GAME"]
P = rows["pack"]
times = json.load(open(os.path.join(out_dir, "fbx_times.json")))
index = json.load(open(index_path, encoding="utf-8"))
notes = json.load(open(os.path.join(ROOT, "tools", "animation_pack", "evaluation_notes.json"), encoding="utf-8"))
# Estado de integracion (selection.json): integrado = tiene disparador real en el juego y prueba; preparado = convertido
# a la libreria local pero sin disparador; el resto no esta convertido.
selection = json.load(open(os.path.join(ROOT, "tools", "animation_pack", "selection.json"), encoding="utf-8"))
STATE = {}
for c in selection["clips"]:
    STATE[c["source"]] = "integrado" if c["state"] == "integrated" else "galería"
date = os.environ.get("DOCS_DATE") or datetime.date.today().isoformat()

GROUPS = [("01_portero", "Portero"), ("02_balon_pases_tiros", "Con el balón"), ("03_defensa_faltas_caidas", "Defensa, faltas y caídas"),
          ("04_movimiento_en_cancha", "Movimiento en la cancha"), ("05_festejos_y_reacciones", "Festejos y reacciones"), ("06_arbitro_y_calentamiento", "Árbitro y calentamiento")]
REC = {"USAR": "**USAR**", "CANDIDATO": "candidato", "RESERVAR": "reservar", "NO": "**NO**"}

lines = []
w = lines.append
w("# Pack de animaciones de fútbol — tabla de los 133 clips")
w("")
w(f"> Generado por `tools/animation_pack/make_report.py` el {date} (no editar a mano: editar `tools/animation_pack/evaluation_notes.json` y regenerar).")
w("> Resumen, comparativa con Tripo, incompatibilidades y plan de migración: [SYSTEMS/ANIMATION_PACK.md](SYSTEMS/ANIMATION_PACK.md).")
w("")
w("**Cómo leer la tabla**")
w("")
w("- **Dur.**: duración del clip tal como la importa Godot, comprobada contra el FBX en bruto. Entre corchetes, la duración que declara `indice_futbol.json` cuando difiere en más de 0.06 s.")
w("- **Pistas/huesos**: pistas de animación y huesos animados (el esqueleto del pack tiene 65 huesos; el de Tripo, 23, de los que 22 tienen equivalente).")
w(f"- **Raíz**: desplazamiento horizontal de la cadera entre el primer y el último fotograma, en metros del Y Bot, y entre paréntesis la velocidad equivalente **en nuestro futbolista** (× {k_game:.3f}, por altura de cadera). `0` = el clip no traslada al personaje.")
w("- **Ciclo**: diferencia angular media y máxima entre el primer y el último fotograma (0 = el bucle cierra sin salto).")
w("- **Visto**: `sí` = se reprodujo sobre nuestro futbolista de Tripo en Godot y se miró la hoja de contacto; `gemelo` = su versión con/sin raíz sí se vio y sus rotaciones coinciden (≤ 0.16°); `no` = solo métricas.")
w("- **Rec.**: **USAR** = cubre una necesidad del núcleo y se vio bien; *candidato* = cubre una necesidad pero falta verla; *reservar* = útil más adelante o no necesario para el núcleo; **NO** = inadecuado para lo que sugiere su nombre.")
w("- **Estado**: `integrado` = convertido a las librerías del juego y citado por el código de juego (disparador en partido, arquero o malabares); `galería` = convertido y reproducible en la sala de práctica (con su espejo si lo tiene) pero sin disparador en el partido; `no convertido` = solo evaluado. Ver [SYSTEMS/ANIMATION_PACK.md](SYSTEMS/ANIMATION_PACK.md).")
w("- **Ola**: 1 locomoción y balón · 2 defensa/caídas/saltos · 3 portero · 4 festejos y reacciones · 5 modo práctica/otros · 0 no aplica (gemelo o descartado).")
w("")
counts = collections.Counter()
for g, title in GROUPS:
    items = [i for i in index if i["grupo"] == g]
    w(f"## {title} (`animaciones/{g}/`, {len(items)})")
    w("")
    w("| Archivo | Dur. s | Pistas/huesos | Raíz m (m/s en juego) | Ciclo (media/máx °) | Visto | Rec. | Ola | Estado | Nota |")
    w("|---|---|---|---|---|---|---|---|---|---|")
    for it in items:
        rel = it["archivo_en_zip"].split("animaciones/")[1]
        m = P[rel]
        t = times.get(rel)
        dur = f"{m['dur']:.2f}"
        if abs(m["dur"] - it["duracion_s"]) > 0.06:
            dur += f" [{it['duracion_s']:.2f}]"
        rd = m["root"][2] if m["root"] else 0.0
        root = "0" if rd < 0.05 else f"{rd:.2f} ({rd / m['dur'] * k_game:.2f})"
        n = notes[rel]
        base = os.path.basename(rel)[:-4]
        twin = base + "_inplace" if not base.endswith("_inplace") else base[: -len("_inplace")]
        twin_rel = os.path.join(os.path.dirname(rel), twin + ".fbx")
        seen = "sí" if n["visual"] else ("gemelo" if twin_rel in notes and notes[twin_rel]["visual"] else "no")
        counts[(g, n["rec"])] += 1
        w(f"| `{os.path.basename(rel)}` | {dur} | {m['tracks']}/{m['bones']} | {root} | {m['loop_gap_mean']:.1f}/{m['loop_gap_max']:.0f} | {seen} | {REC[n['rec']]} | {n['ola']} | {STATE.get(rel, 'no convertido')} | {n['nota']} |")
    w("")
tot = collections.Counter(n["rec"] for n in notes.values())
w("## Totales")
w("")
st = collections.Counter(STATE.get(r, "no convertido") for r in notes)
w(f"- Estado de integración: integrado {st['integrado']}; galería {st['galería']}; no convertido {st['no convertido']} (los espejos izquierdos de pase/tiro/Chip/penalti se generan al convertir y no cuentan aparte).")
w(f"- Clips: {len(notes)}; vistos sobre nuestro futbolista: {sum(1 for n in notes.values() if n['visual'])}; USAR: {tot['USAR']}; candidato: {tot['CANDIDATO']}; reservar: {tot['RESERVAR']}; NO: {tot['NO']}.")
open(md_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("escrito", md_path, len(lines), "lineas")
