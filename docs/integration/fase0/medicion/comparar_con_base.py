#!/usr/bin/env python3
"""Compara las metricas de partido de una etapa con la linea base (medias de los partidos de 10 min con las mismas
semillas) y aplica los umbrales de aborto de AUDITORIA_PRE_IMPLEMENTACION.md §10.

Uso: python3 comparar_con_base.py <metricas.json base>[,<otro.json>...] <metricas.json etapa>[,<otro.json>...] [--md salida.md]
Varios archivos separados por comas se juntan (p. ej. las 6 semillas de la base y 6 semillas mas, para confirmar con 12
partidos como pide el §10 cuando el ruido es del orden del umbral).
Salida: tabla (texto o Markdown) y codigo 1 si algun umbral de aborto se supera. La ultima columna es el p bilateral de
una prueba de permutacion de la diferencia de medias por partido: informa si la diferencia se distingue del ruido entre
partidos, pero NO cambia el estado (un umbral superado se informa siempre como SUPERA).
"""
import json
import random
import statistics
import sys

# (metrica, regla, umbral, descripcion). Reglas: rel = aumento relativo maximo; pp = aumento absoluto maximo (puntos);
# abs = valor maximo; min = no bajar del minimo por partido de la base.
THRESHOLDS = [
    ("contacto_dist_p90", "rel", 0.10, "p90 distancia pelota-contacto"),
    ("pct_golpeos_iniciados_sin_contacto", "pp", 5.0, "% golpeos iniciados sin contacto"),
    ("pct_mov_pelota_cortados", "pp", 5.0, "% movimientos con pelota cortados"),
    ("pct_recepciones_clip_abortadas", "pp", 5.0, "% recepciones con clip abortadas"),
    ("goles_en_propia", "abs", 1.5, "goles en propia por partido"),
    ("pct_perdida_tras_recepcion_animada", "rel", 0.05, "% perdida tras recepcion animada"),
    ("goles", "min", None, "goles por partido"),
]
EXTRA = ["contacto_dist_mediana", "contacto_dist_p95", "contacto_dist_max", "pct_contactos_hasta_020", "pct_contactos_hasta_030", "pct_contactos_mas_030", "golpeos_iniciados", "golpeos_aereos",
         "pct_rasos_fallidos", "recepciones_clip_iniciadas", "pct_primeros_toques_con_clip", "pct_arbitro_rechazadas",
         "tramos_reproducidos", "roles_reproducidos", "pct_clip_mas_repetido", "pases", "tiros", "script_errors"]


def tenmin(paths):
    rows = []
    for p in paths.split(","):
        rows += [r for r in json.load(open(p))["por_partido"] if not r["partido"].endswith(("_repeticion", "_render"))]
    return rows


def perm_p(b, n, k, reps=20000):
    """p bilateral de una prueba de permutacion de la diferencia de medias por partido (semilla fija: reproducible)."""
    x = [r[k] for r in b if r.get(k) is not None]
    y = [r[k] for r in n if r.get(k) is not None]
    if len(x) < 2 or len(y) < 2:
        return None
    obs = abs(statistics.mean(y) - statistics.mean(x))
    allv = x + y
    rng = random.Random(1)
    hits = 0
    for _ in range(reps):
        rng.shuffle(allv)
        if abs(statistics.mean(allv[len(x):]) - statistics.mean(allv[:len(x)])) >= obs - 1e-12:
            hits += 1
    return hits / reps


def stats(rows, k):
    v = [r[k] for r in rows if r.get(k) is not None]
    return (statistics.mean(v), min(v), max(v)) if v else (None, None, None)


def main():
    md = sys.argv[sys.argv.index("--md") + 1] if "--md" in sys.argv else None
    b, n = tenmin(sys.argv[1]), tenmin(sys.argv[2])
    lines = ["| Metrica | Base (media; min-max) | Etapa (media; min-max) | Umbral de aborto | Estado | p (permutacion) |",
             "|---|---|---|---|---|---|"]
    abort = False
    for k, rule, thr, desc in THRESHOLDS:
        bm, bmin, bmax = stats(b, k)
        nm, nmin, nmax = stats(n, k)
        if bm is None or nm is None:
            lines.append("| %s | %s | %s | — | sin datos | — |" % (desc, bm, nm))
            continue
        if rule == "rel":
            lim = bm * (1 + thr); bad = nm > lim; lim_s = "<= %.3f (+%d %%)" % (lim, thr * 100)
        elif rule == "pp":
            lim = bm + thr; bad = nm > lim; lim_s = "<= %.2f (+%.0f pp)" % (lim, thr)
        elif rule == "abs":
            lim = thr; bad = nm > lim; lim_s = "<= %.2f" % lim
        else:
            lim = bmin; bad = nm < lim; lim_s = ">= %.2f (minimo de la base)" % lim
        abort = abort or bad
        pv = perm_p(b, n, k)
        lines.append("| %s | %.3f; %.3f-%.3f | %.3f; %.3f-%.3f | %s | %s | %s |" % (desc, bm, bmin, bmax, nm, nmin, nmax, lim_s,
                                                                         "SUPERA" if bad else "ok", "%.3f" % pv if pv is not None else "—"))
    for k in EXTRA:
        bm, bmin, bmax = stats(b, k)
        nm, nmin, nmax = stats(n, k)
        if bm is None or nm is None:
            continue
        pv = perm_p(b, n, k)
        lines.append("| %s | %.3f; %.3f-%.3f | %.3f; %.3f-%.3f | (seguimiento) | — | %s |" % (k, bm, bmin, bmax, nm, nmin, nmax,
                                                                                   "%.3f" % pv if pv is not None else "—"))
    out = "\n".join(lines)
    print(out)
    print("\nPartidos: base %d %s · etapa %d %s" % (len(b), [r["partido"] for r in b], len(n), [r["partido"] for r in n]))
    print("RESULTADO: %s" % ("SUPERA UN UMBRAL DE ABORTO" if abort else "dentro de los umbrales"))
    if md:
        open(md, "w").write(out + "\n\nPartidos de 10 min: base %d, etapa %d.\n" % (len(b), len(n)))
    sys.exit(1 if abort else 0)


if __name__ == "__main__":
    main()
