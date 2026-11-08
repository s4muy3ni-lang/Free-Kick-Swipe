"""Estadisticas de los 52 campos int16 de animdb.adb de UCS (para docs/transferencia_integracion_completa/DATOS_UCS.md).

No asigna significados: por campo da minimo, maximo, valores distintos, % de ceros, como se comporta en el par
original/espejo (registro 2k / 2k+1) y su correlacion con lo que medimos en nuestro banco (cuadros, giro yaw_end,
v_in, v_out). Sirve para saber que campos estan sin identificar y cuales tienen pistas.

Uso: python3 tools/transfer/adb_field_stats.py <animdb.adb> <index.json del banco> > salida.md
"""
import json
import math
import struct
import sys


def records(path):
    d = open(path, "rb").read()
    n = struct.unpack_from("<I", d, 0)[0]
    recs = [struct.unpack_from("<52h", d, 4 + i * 104) for i in range(n)]
    tail = len(d) - 4 - n * 104
    return recs, tail, len(d)


def corr(a, b):
    n = len(a)
    if n < 10:
        return float("nan")
    ma = sum(a) / n
    mb = sum(b) / n
    sa = math.sqrt(sum((x - ma) ** 2 for x in a))
    sb = math.sqrt(sum((y - mb) ** 2 for y in b))
    if sa == 0 or sb == 0:
        return float("nan")
    return sum((x - ma) * (y - mb) for x, y in zip(a, b)) / (sa * sb)


def main():
    recs, tail, size = records(sys.argv[1])
    bank = json.load(open(sys.argv[2], encoding="utf-8"))["clips"]
    meta = {}
    for c in bank:
        meta[int(c["file"][:4])] = c
    print("Archivo: %d bytes; %d registros de 104 bytes; cola sin decodificar: %d bytes\n" % (size, len(recs), tail))
    print("| campo | min | max | distintos | % ceros | espejo (2k+1 frente a 2k) | correlacion con nuestro banco (r > 0.5) |")
    print("|---:|---:|---:|---:|---:|---|---|")
    pairs = [(recs[2 * k], recs[2 * k + 1]) for k in range(len(recs) // 2)]
    for f in range(52):
        vals = [r[f] for r in recs]
        nz = sum(1 for v in vals if v == 0)
        eq = sum(1 for a, b in pairs if a[f] == b[f])
        neg = sum(1 for a, b in pairs if a[f] == -b[f] and a[f] != 0)
        nonzero_pairs = sum(1 for a, b in pairs if a[f] != 0 or b[f] != 0)
        if nonzero_pairs == 0:
            mirror = "siempre 0"
        elif eq == len(pairs):
            mirror = "igual en los dos"
        elif neg >= 0.9 * nonzero_pairs:
            mirror = "cambia de signo (%d/%d)" % (neg, nonzero_pairs)
        else:
            mirror = "igual %d, signo cambiado %d, otro %d (de %d)" % (eq, neg, len(pairs) - eq - neg, len(pairs))
        cors = []
        for name, key in (("cuadros", "frames"), ("yaw_end", "yaw_end"), ("v_in", "v_in"), ("v_out", "v_out")):
            xs = []
            ys = []
            # El numero NNNN del archivo JSON es el indice del registro (comprobado con los cuadros: 2022/2022).
            for k, c in meta.items():
                if k >= len(recs):
                    continue
                y = c.get(key) if key == "frames" else c.get("meta", {}).get(key)
                if y is None:
                    continue
                xs.append(recs[k][f])
                ys.append(float(y))
            r = corr(xs, ys)
            if not math.isnan(r) and abs(r) > 0.5:
                cors.append("%s %.2f" % (name, r))
        print("| %d | %d | %d | %d | %.0f | %s | %s |" % (f, min(vals), max(vals), len(set(vals)), 100.0 * nz / len(vals), mirror, ", ".join(cors) or "-"))


if __name__ == "__main__":
    main()
