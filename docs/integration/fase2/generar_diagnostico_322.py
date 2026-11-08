#!/usr/bin/env python3
"""Fase 2: tabla de diagnostico de los 322 segmentos conectados pero no seleccionables.

Entradas:
  --meta      metadatos de los clips volcados del juego (escena res://zz_meta322.tscn, ver --volcar)
  --estado    docs/integration/estado_individual.csv (inventario: conexion y filtro historicos)
  --index     index.json del ZIP de los 2.022 JSON originales (nombres originales)
Salida: docs/integration/fase2/diagnostico_322.csv y un resumen por decision en la salida estandar.

Las decisiones siguen la seccion 4.2 de la guia: valido, valido con contexto, valido con evento alternativo, solo
presentacion, pendiente_revision_visual_especializada, incompatible. Ningun JSON original se modifica.
"""
import argparse
import collections
import csv
import json

COLS = ["segment_id", "fuente_json", "nombre_original", "rol_efectivo", "sistema_consumidor", "filtro", "dato",
        "valor_medido", "umbral", "causa_probable", "accion_recomendada", "decision", "estado_revision", "prueba"]

LATERAL_MAX = 0.75  # JsonCatalog.KICK_LATERAL_MAX


def clean_failures(ct):
    f = []
    if ct["y"] > 0.3: f.append("pie_alto")
    if ct["x"] < 0.0: f.append("detras")
    if ct["x"] > 0.95: f.append("lejos_delante")
    if abs(ct["z"]) > 0.5: f.append("costado")
    if ct["speed"] < 4.0: f.append("pie_lento")
    if ct["plant_y"] > 0.06: f.append("apoyo_alto")
    if abs(ct["kick_turn"]) >= 45.0: f.append("giro")
    if ct["plant_slide"] > 1.2: f.append("apoyo_patina")
    if not ct["planted"]: f.append("apoyo_no_plantado")
    return f


def row_situation(sid, m, name):
    base = {"sistema_consumidor": "JsonCatalog.situation_clip (festejos, lamentos, gestos, barrera, calentamiento)",
            "filtro": "AnimDB.candidates(max_root=1.0, min_duration=0.6)"}
    if m["root_len"] > 1.0:
        return dict(base, dato="recorrido de raiz", valor_medido="%.2f m" % m["root_len"], umbral="<= 1.00 m",
                    causa_probable="clip con desplazamiento (festejo, lamento o gesto en movimiento); el selector de situaciones lo reproduce en el sitio y el cuerpo quedaria deslizando o desfasado",
                    accion_recomendada="consumidor que aplique la raiz (como PlayerActions/ActionMotion) en festejos y lamentos; no relajar el filtro en el sitio",
                    decision="valido con contexto", estado_revision="decidido; no habilitado: falta consumidor con raiz", prueba="")
    if "END" in name.upper().split("_")[-1] or "_END" in name.upper():
        return dict(base, dato="duracion", valor_medido="%.2f s" % m["duration"], umbral=">= 0.60 s",
                    causa_probable="fragmento final de otro clip (sufijo END)",
                    accion_recomendada="conservar; solo como cola del clip principal",
                    decision="incompatible", estado_revision="decidido", prueba="")
    loop_role = m["role"] in ("wall", "jostle", "nis_idle") or "LOOP" in name.upper()
    if m["loop"] and m["duration"] >= 0.2 and loop_role:
        return dict(base, dato="duracion", valor_medido="%.2f s (bucle)" % m["duration"], umbral=">= 0.60 s",
                    causa_probable="ciclo corto en bucle (barrera, forcejeo, espera): el selector lo trata como pose de una sola vez",
                    accion_recomendada="reproducirlo en bucle durante la situacion (barrera, forcejeo, espera)",
                    decision="valido con contexto", estado_revision="decidido; no habilitado: falta reproduccion en bucle", prueba="")
    return dict(base, dato="duracion", valor_medido="%.2f s" % m["duration"], umbral=">= 0.60 s",
                causa_probable="clip corto: fragmento, bucle de muy pocos cuadros o gesto que no corresponde a su rol",
                accion_recomendada="inspeccion visual de la hoja de poses antes de decidir",
                decision="pendiente_revision_visual_especializada", estado_revision="fuera del catalogo activo", prueba="")


def row_kick(sid, m, name):
    ct = m["contact"]
    f = clean_failures(ct)
    vals = {"pie_alto": "punta %.2f m (<= 0.30)" % ct["y"], "detras": "x %.2f m (>= 0)" % ct["x"],
            "lejos_delante": "x %.2f m (<= 0.95)" % ct["x"], "costado": "|z| %.2f m (<= 0.50)" % abs(ct["z"]),
            "pie_lento": "pie %.1f m/s (>= 4.0)" % ct["speed"], "apoyo_alto": "apoyo %.2f m (<= 0.06)" % ct["plant_y"],
            "giro": "giro %.0f grados (< 45)" % abs(ct["kick_turn"]), "apoyo_patina": "apoyo %.2f m/s (<= 1.2)" % ct["plant_slide"],
            "apoyo_no_plantado": "apoyo no plantado en los 0.1 s previos"}
    base = {"sistema_consumidor": "JsonCatalog.kick_candidates -> BallHandler.plan_clip_kick",
            "filtro": "contact.clean (8 condiciones del conversor)", "dato": ", ".join(f),
            "valor_medido": "; ".join(vals[x] for x in f), "umbral": "todas las condiciones de golpeo limpio"}
    if f == ["costado"] and abs(ct["z"]) <= LATERAL_MAX:
        return dict(base, causa_probable="umbral lateral de 0.50 m demasiado estricto: cumple las otras 7 condiciones (pie bajo y rapido, apoyo plantado y quieto, salida recta)",
                    accion_recomendada="admitir el costado hasta %.2f m solo para estos (JsonCatalog.KICK_LATERAL_MAX); el planificador sigue exigiendo que el pie llegue" % LATERAL_MAX,
                    decision="valido", estado_revision="habilitado", prueba="tests/test_kick_recovery.gd")
    if "pie_alto" in f:
        return dict(base, causa_probable="la punta golpea a media altura: es un golpeo de semivolea o volea, no raso",
                    accion_recomendada="ofrecerlo al planificador aereo con la pelota a esa altura (evento de contacto alto ya medido)",
                    decision="valido con evento alternativo", estado_revision="decidido; no habilitado: requiere planificador de media altura", prueba="")
    if "detras" in f:
        return dict(base, causa_probable="contacto detras del cuerpo (taconazo o golpeo cruzado por detras)",
                    accion_recomendada="inspeccion visual; si es taconazo, rol kick_back con su propio evento",
                    decision="pendiente_revision_visual_especializada", estado_revision="fuera del catalogo activo", prueba="")
    if "apoyo_patina" in f or "apoyo_no_plantado" in f or "apoyo_alto" in f:
        return dict(base, causa_probable="el pie de apoyo aterriza o patina en los 0.1 s previos al contacto: jugado con el cuerpo plantado del golpeo raso, el pie patina",
                    accion_recomendada="solo con un golpeo que siga la raiz y la carrera del clip; con el golpeo raso actual no",
                    decision="incompatible", estado_revision="decidido (incompatible con el golpeo raso actual; se conserva)", prueba="")
    if "pie_lento" in f:
        return dict(base, causa_probable="pie lento en el contacto: toque suave, control o gesto sin golpeo real",
                    accion_recomendada="inspeccion visual; si es un toque suave, consumidor de conduccion o pase muy corto",
                    decision="pendiente_revision_visual_especializada", estado_revision="fuera del catalogo activo", prueba="")
    return dict(base, causa_probable="contacto demasiado al costado (> %.2f m)" % LATERAL_MAX,
                accion_recomendada="inspeccion visual", decision="pendiente_revision_visual_especializada",
                estado_revision="fuera del catalogo activo", prueba="")


def row_touches(sid, m, name, ucs):
    base = {"sistema_consumidor": "JsonBallMove.plan_ids (giros y paradas con pelota)", "filtro": "meta ball_touches no vacio",
            "dato": "toques de pelota medidos", "valor_medido": "0", "umbral": ">= 1"}
    if sid == "jn_ball_start_3066":
        return dict(base, causa_probable="no tiene toques de conduccion, pero tiene perfil de recepcion usable",
                    accion_recomendada="ninguna: lo selecciona JsonReceive", decision="valido",
                    estado_revision="seleccionable por otro consumidor (JsonReceive)", prueba="tests/test_receive.gd (perfiles)")
    if not ucs.get("toque_pie"):
        return dict(base, causa_probable="gira con la pelota en las manos (saque de banda), no con el pie",
                    accion_recomendada="no ofrecerlo a giros con pelota; candidato a la preparacion del saque",
                    decision="incompatible", estado_revision="decidido", prueba="")
    return dict(base, valor_medido="0 (UCS: cuadro %s, pie %s)" % (ucs.get("toque_cuadro"), ucs.get("toque_pie")),
                causa_probable="el inventario UCS da el instante y el pie del toque, pero la conversion no genero el toque medido (posicion de la punta)",
                accion_recomendada="generar el toque desde la pose del clip en ese cuadro con la herramienta de conversion (Fase 10); no inventarlo",
                decision="valido con evento alternativo", estado_revision="decidido; no habilitado: falta convertir el evento", prueba="")


def row_high_turn(sid, m, name):
    ct = m["contact"]
    return {"sistema_consumidor": "BallHandler.plan_turn_kick (golpeo girando, kick_turn / kick_back)",
            "filtro": "punta <= 0.35 m en el contacto", "dato": "altura de la punta", "valor_medido": "%.2f m" % ct["y"],
            "umbral": "<= 0.35 m",
            "causa_probable": "golpeo girando con la pelota a media altura (flick, volea corta, taconazo alto)",
            "accion_recomendada": "ofrecerlo con la pelota a esa altura (planificador aereo / semivolea), no a ras",
            "decision": "valido con evento alternativo", "estado_revision": "decidido; no habilitado: requiere planificador de media altura",
            "prueba": ""}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--meta", required=True)
    ap.add_argument("--estado", required=True)
    ap.add_argument("--index", required=True)
    ap.add_argument("--animdb", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    meta = json.load(open(a.meta))
    clips_ix = json.load(open(a.index))["clips"]
    names = {c["file"][:4]: c["name"] for c in clips_ix}
    files = {c["file"][:4]: c["file"] for c in clips_ix}
    ucs = {k: v.get("ucs", {}) for k, v in json.load(open(a.animdb))["clips"].items()}
    rows = [r for r in csv.DictReader(open(a.estado)) if r["estado_conexion"] == "si" and r["filtro_del_sistema"].startswith("no pasa")]
    out = []
    for r in rows:
        sid = r["id_juego"]
        m = meta[sid]
        src = sid[-4:]
        name = names.get(src, r["nombre_ucs"])
        flt = r["filtro_del_sistema"]
        if "situation" in flt:
            d = row_situation(sid, m, name)
        elif "limpio" in flt:
            d = row_kick(sid, m, name)
        elif "toques" in flt:
            d = row_touches(sid, m, name, ucs.get(src, {}))
        else:
            d = row_high_turn(sid, m, name)
        d.update({"segment_id": sid, "fuente_json": files.get(src, ""), "nombre_original": name,
                  "rol_efectivo": m["role"]})
        out.append(d)
    with open(a.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLS)
        w.writeheader()
        for d in out:
            w.writerow({c: d.get(c, "") for c in COLS})
    c = collections.Counter(d["decision"] for d in out)
    s = collections.Counter(d["estado_revision"] for d in out)
    print(json.dumps({"segmentos": len(out), "por_decision": c, "por_estado": s}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
