"""Verifica las referencias de docs/transferencia_integracion_completa/*.md contra el repositorio:

1. Rutas citadas entre comillas invertidas (scripts/..., tools/..., docs/..., assets/..., tests/..., res://...) y
   enlaces Markdown relativos: el archivo existe. Con «:N» o «:N-M», el archivo tiene al menos esa cantidad de lineas.
2. Archivos citados solo por nombre con linea (`ball_handler.gd:1271`): el nombre es unico en el repositorio y la linea
   existe.
3. `Clase.miembro` con Clase = un class_name del repositorio: el miembro existe en su archivo (func, const, var,
   signal, enum).
4. `Clase.funcion` (N): la funcion esta definida en la linea N.
Las rutas de archivos externos (banco JSON, APK de UCS) se ignoran: se listan en EXTERNAL.

Uso: python3 tools/transfer/check_references.py   (sale con codigo 1 si hay errores)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(ROOT, "docs", "transferencia_integracion_completa")
EXTERNAL = ("animaciones_futbol5", "paquete_recursos_analisis_movimiento", "lib/arm64-v8a", "assets/data/anims",
            "config.arm64_v8a", "1_conectadas", "2_sin_conectar")
SKIP_DIRS = {".git", ".godot", "build", "android"}


def repo_files():
    out = {}
    for dp, dns, fs in os.walk(ROOT):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for f in fs:
            rel = os.path.relpath(os.path.join(dp, f), ROOT)
            out.setdefault(f, []).append(rel)
    return out


def classes():
    """class_name -> archivo; y miembros por archivo con su linea."""
    cls = {}
    members = {}
    for base in ("scripts", "tools", "tests"):
        for dp, _, fs in os.walk(os.path.join(ROOT, base)):
            for f in fs:
                if not f.endswith(".gd"):
                    continue
                rel = os.path.relpath(os.path.join(dp, f), ROOT)
                lines = open(os.path.join(ROOT, rel), encoding="utf-8").read().split("\n")
                mem = {}
                for i, l in enumerate(lines, 1):
                    m = re.match(r"^class_name\s+(\w+)", l)
                    if m:
                        cls[m.group(1)] = rel
                    m = re.match(r"^(?:static\s+)?(?:func|const|var|signal|enum)\s+(\w+)", l)
                    if m:
                        mem.setdefault(m.group(1), i)
                    m = re.match(r"^@export(?:_\w+)?(?:\([^)]*\))?\s+var\s+(\w+)", l)
                    if m:
                        mem.setdefault(m.group(1), i)
                    m = re.match(r"^static\s+var\s+(\w+)", l)
                    if m:
                        mem.setdefault(m.group(1), i)
                    # Clases internas (p. ej. KickModel.KickResult)
                    m = re.match(r"^class\s+(\w+)", l)
                    if m:
                        mem.setdefault(m.group(1), i)
                members[rel] = (mem, len(lines))
    return cls, members


def nlines(path):
    try:
        return len(open(os.path.join(ROOT, path), encoding="utf-8", errors="ignore").read().split("\n"))
    except (IsADirectoryError, FileNotFoundError):
        return -1


def main():
    files = repo_files()
    cls, members = classes()
    errors = []
    checked = {"rutas": 0, "lineas": 0, "simbolos": 0, "lineas_de_funcion": 0, "enlaces": 0}
    for doc in sorted(os.listdir(DOCS)):
        if not doc.endswith(".md"):
            continue
        text = open(os.path.join(DOCS, doc), encoding="utf-8").read()
        # Enlaces Markdown relativos
        for m in re.finditer(r"\]\(([^)#\s]+)(#[^)]*)?\)", text):
            target = m.group(1)
            if target.startswith("http"):
                continue
            p = os.path.normpath(os.path.join(DOCS, target))
            checked["enlaces"] += 1
            if not os.path.exists(p):
                errors.append("%s: enlace roto %s" % (doc, target))
        for m in re.finditer(r"`([^`\n]+)`", text):
            tok = m.group(1).strip()
            after = text[m.end():m.end() + 12]
            # Rutas
            pm = re.match(r"^(res://)?((?:scripts|tools|docs|assets|tests)/[\w./-]+?)(?::(\d+)(?:-(\d+))?(?:,\s*[\d,\s-]+)?)?$", tok)
            if pm:
                if any(e in tok for e in EXTERNAL):
                    continue
                path = pm.group(2).rstrip(".")
                checked["rutas"] += 1
                if not os.path.exists(os.path.join(ROOT, path)):
                    errors.append("%s: no existe %s" % (doc, path))
                    continue
                if pm.group(3):
                    checked["lineas"] += 1
                    last = int(pm.group(4) or pm.group(3))
                    if last > nlines(path):
                        errors.append("%s: %s tiene %d lineas (cita %d)" % (doc, path, nlines(path), last))
                continue
            # Nombre de archivo con linea
            fm = re.match(r"^([\w.-]+\.(?:gd|py|godot|json|csv|tscn|res|md)):(\d+)(?:-(\d+))?(?:,\s*([\d,\s-]+))?$", tok)
            if fm:
                cands = files.get(fm.group(1), [])
                if len(cands) != 1:
                    errors.append("%s: %s ambiguo o inexistente (%d archivos)" % (doc, fm.group(1), len(cands)))
                    continue
                checked["lineas"] += 1
                nums = [int(fm.group(3) or fm.group(2))]
                if fm.group(4):
                    nums += [int(x) for x in re.findall(r"\d+", fm.group(4))]
                if max(nums) > nlines(cands[0]):
                    errors.append("%s: %s tiene %d lineas (cita %d)" % (doc, cands[0], nlines(cands[0]), max(nums)))
                continue
            # Clase.miembro
            sm = re.match(r"^([A-Z]\w+)\.(\w+)(?:\(.*\))?$", tok)
            if sm and sm.group(1) in cls:
                c, mbr = sm.group(1), sm.group(2)
                checked["simbolos"] += 1
                mem, _ = members[cls[c]]
                if mbr not in mem:
                    errors.append("%s: %s.%s no existe en %s" % (doc, c, mbr, cls[c]))
                    continue
                lm = re.match(r"^ \((\d+)\)", after)
                if lm:
                    checked["lineas_de_funcion"] += 1
                    if int(lm.group(1)) != mem[mbr]:
                        errors.append("%s: %s.%s esta en la linea %d (cita %s)" % (doc, c, mbr, mem[mbr], lm.group(1)))
    for e in errors:
        print("ERROR", e)
    print("comprobado:", checked, "errores:", len(errors))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
