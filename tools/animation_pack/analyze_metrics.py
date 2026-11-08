import json, math, re, sys
SP = sys.argv[1]
d = json.load(open(f"{SP}/metrics.json"))
YB_HIPS = d["skeletons"]["ybot_tpose"]["hips_rest_y"]
TR_HIPS = d["skeletons"]["tripo_player_base"]["hips_rest_y"]
K_GAME = TR_HIPS * 1.75 / YB_HIPS

def v3(s):
    if isinstance(s, list): return s
    return [float(x) for x in re.findall(r"-?\d+\.?\d*(?:e-?\d+)?", s)][:3]

def ground(m, scale):
    """Velocidad del suelo bajo el pie de apoyo (el mas bajo) respecto a la cadera, vector horizontal en el esqueleto."""
    s = m.get("_series")
    if not s or m["length"] < 0.2: return None
    dt = m["length"] / m["series_steps"]
    miny = m["foot_min_y"]
    vel = []
    prev = None
    for hp, lf, rf in s:
        hp, lf, rf = v3(hp), v3(lf), v3(rf)
        which = 0 if lf[1] <= rf[1] else 1
        lo = lf if which == 0 else rf
        rel = (lo[0]-hp[0], lo[2]-hp[2])
        planted = lo[1] < miny + 0.05 * max(hp[1], 0.01)
        if prev is not None and planted and prev[1] and prev[2] == which:
            vel.append(((rel[0]-prev[0][0])/dt, (rel[1]-prev[0][1])/dt))
        prev = (rel, planted, which)
    if len(vel) < 3: return None
    return (-sum(p[0] for p in vel)/len(vel)*scale, -sum(p[1] for p in vel)/len(vel)*scale)

def hips_y(m):
    s = m.get("_series")
    ys = [v3(x[0])[1] for x in s] if s else []
    return (sum(ys)/len(ys), min(ys), max(ys)) if ys else (0, 0, 0)

def root(m, scale):
    if "hips_first" not in m: return None
    a, b = v3(m["hips_first"]), v3(m["hips_last"])
    dx, dz = (b[0]-a[0])*scale, (b[2]-a[2])*scale
    return dx, dz, math.hypot(dx, dz)

out = {"K_GAME": K_GAME, "pack": {}, "tripo": {}}
for k, e in d["pack"].items():
    m = e["metrics"]
    g = ground(m, 1.0)
    r = root(m, 1.0)
    out["pack"][k] = {"dur": m["length"], "tracks": m["tracks"], "bones": m["bones_animated"], "pos_tracks": m["pos_tracks"],
        "root": r, "ground": g, "loop_gap_mean": m["loop_gap_mean_deg"], "loop_gap_max": m["loop_gap_max_deg"],
        "hips_ratio": hips_y(m)[0]/YB_HIPS, "hips_min": hips_y(m)[1]/YB_HIPS, "hips_max": hips_y(m)[2]/YB_HIPS}
for k, m in d["tripo"].items():
    g = ground(m, 1.75)
    r = root(m, 1.75)
    out["tripo"][k] = {"dur": m["length"], "tracks": m["tracks"], "loop_mode": m["loop_mode"], "root": r, "ground": g,
        "loop_gap_mean": m["loop_gap_mean_deg"], "loop_gap_max": m["loop_gap_max_deg"],
        "hips_ratio": hips_y(m)[0]/TR_HIPS, "hips_min": hips_y(m)[1]/TR_HIPS, "hips_max": hips_y(m)[2]/TR_HIPS}
json.dump(out, open(f"{SP}/rows.json", "w"))
print("factor Y Bot -> nuestro futbolista (altura de cadera):", round(K_GAME, 3), "| cadera Y Bot", round(YB_HIPS, 3), "Tripo", round(TR_HIPS, 3))
print("== Tripo (13 clips): duracion, pistas, cierre de ciclo medio/max, cadera media (rango) relativa al reposo, movimiento raiz total, velocidad del suelo (m/s en juego)")
for k, t in sorted(out["tripo"].items()):
    g = ("(%.2f,%.2f)" % t["ground"]) if t["ground"] else "-"
    print("%-18s %6.2fs pistas=%d bucle=%d ciclo=%.1f/%.0f deg cadera=%.2f (%.2f-%.2f) raiz=%.2f m suelo(x,z)=%s" % (k, t["dur"], t["tracks"], t["loop_mode"], t["loop_gap_mean"], t["loop_gap_max"], t["hips_ratio"], t["hips_min"], t["hips_max"], t["root"][2], g))
