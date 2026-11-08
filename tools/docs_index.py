#!/usr/bin/env python3
"""Herramienta del indice tecnico (docs/technical-index). Solo biblioteca estandar.

El indice documenta el codigo REAL: lo que cambia con el codigo (lineas, valores por defecto, listas de
funciones, senales, pruebas, acciones de entrada) se genera leyendo los archivos; lo que requiere criterio
(descripciones, flujos, palabras clave) se escribe a mano.

Comandos:
  sync                 regenera los bloques <!-- AUTO:... --> de los .md y los campos derivados de CODE_MAP.json
  check                valida rutas, simbolos, parametros, JSON y bloques AUTO; sale con 1 si hay desfases
  find <terminos...>   busca en CODE_MAP.json (espanol/ingles) y muestra archivos, simbolos y ficha
  where <Simbolo>      localiza un simbolo (Clase.metodo, Clase.parametro, Clase.CONST) con linea y referencias
  stats                resumen del escaneo (archivos, simbolos)

Bloques AUTO (dentro de los .md; todo entre las marcas se reescribe en `sync`):
  <!-- AUTO:params:NombreDeClase -->   tabla de parametros (@export / var) con defecto, rango, linea y referencias
  <!-- AUTO:funcs:ruta/archivo.gd --> funciones con linea y primera linea de su comentario ##
  <!-- AUTO:consts:ruta/archivo.gd --> constantes
  <!-- AUTO:signals:ruta/archivo.gd --> senales
  <!-- AUTO:constdef:ruta/archivo.gd#NOMBRE --> texto exacto de una constante (incluso multilinea)
  <!-- AUTO:tests:ruta/test.gd -->    metodos test_* con linea
  <!-- AUTO:attrs -->                  atributos de PlayerAttributes y su uso real en el codigo
  <!-- AUTO:inputs -->                 acciones de InputMap con teclas (project.godot)
  <!-- AUTO:layers -->                 capas de fisica 3D con nombre (project.godot)
  <!-- AUTO:autoloads -->              autoloads (project.godot)
  <!-- AUTO:verified -->               fecha de la ultima sincronizacion
Fecha: variable de entorno DOCS_DATE o la fecha del sistema.
"""
import datetime
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS = os.path.join(ROOT, "docs", "technical-index")
CODE_MAP = os.path.join(DOCS, "CODE_MAP.json")
SCAN_DIRS = ["scripts", "scenes", "assets", "tests", "tools", "resources"]
SCAN_EXT = (".gd", ".gdshader", ".tscn", ".tres", ".py", ".sh")

RE_CLASS_NAME = re.compile(r"^class_name\s+(\w+)")
RE_EXTENDS = re.compile(r"^extends\s+(.+?)\s*$")
RE_INNER = re.compile(r"^class\s+(\w+)\s*(?:extends\s+[\w\.]+)?\s*:")
RE_FUNC_START = re.compile(r"^(\t*)(?:static\s+)?func\s+(\w+)\s*\((.*)$")
RE_SIGNAL = re.compile(r"^signal\s+(\w+)\s*(\(.*\))?")
RE_CONST = re.compile(r"^const\s+(\w+)\s*(?::\s*[\w\.\[\]]+)?\s*:?=\s*(.*)$")
RE_ENUM = re.compile(r"^enum\s+(\w+)\s*\{(.*)$")
RE_VAR = re.compile(
    r"^(?P<ann>(?:@export\w*(?:\([^)]*\))?\s+|@onready\s+)*)(?:static\s+)?var\s+(?P<name>\w+)"
    r"\s*(?::\s*(?P<type>[\w\.\[\], ]+?))?\s*(?::?=\s*(?P<default>.*))?$")
RE_EXPORT_RANGE = re.compile(r"@export_range\(([^)]*)\)")
RE_EXPORT_GROUP = re.compile(r'^@export_group\("([^"]*)"\)')
RE_PATH_TOKEN = re.compile(r"^(?:(?:scripts|scenes|assets|tools|tests|docs|resources|\.github)/[\w\-./]+|project\.godot|CLAUDE\.md|icon\.svg)$")


def today():
    return os.environ.get("DOCS_DATE") or datetime.date.today().isoformat()


def strip_comment(text):
    """Quita un comentario # final respetando las comillas."""
    out = []
    quote = None
    for ch in text:
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#":
            break
        else:
            out.append(ch)
    return "".join(out).strip()


class Symbol:
    def __init__(self, kind, name, line, file, owner=None, **extra):
        self.kind = kind          # func | var | const | signal | enum | class
        self.name = name
        self.line = line
        self.file = file
        self.owner = owner        # clase propietaria (class_name o clase interna)
        self.extra = extra

    @property
    def qualified(self):
        return f"{self.owner}.{self.name}" if self.owner else self.name


class FileInfo:
    def __init__(self, path):
        self.path = path
        self.class_name = None
        self.extends = None
        self.symbols = []
        self.lines = []

    def find(self, qualified):
        for s in self.symbols:
            if s.qualified == qualified:
                return s
        return None


def scan_gd(path, autoload_name=None):
    info = FileInfo(path)
    info.autoload = autoload_name
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        raw = f.read().split("\n")
    info.lines = raw
    owner_stack = [None]
    inner_name = None
    group = ""
    doc = []
    in_enum = None
    skip_until = 0
    for i, line in enumerate(raw, 1):
        if i <= skip_until:
            continue
        stripped = line.strip()
        if stripped.startswith("##"):
            doc.append(stripped.lstrip("#").strip())
            continue
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip("\t"))
        if in_enum is not None:
            in_enum["body"] += " " + strip_comment(stripped)
            if "}" in stripped:
                names = [n.split("=")[0].strip() for n in in_enum["body"].split("}")[0].split(",") if n.strip()]
                info.symbols.append(Symbol("enum", in_enum["name"], in_enum["line"], path, owner_stack[-1] if inner_name else info.class_name, values=names, doc=in_enum["doc"]))
                in_enum = None
            doc = []
            continue
        if indent == 0:
            inner_name = None if not RE_INNER.match(line) else inner_name
            m = RE_CLASS_NAME.match(line)
            if m:
                info.class_name = m.group(1)
                doc = []
                continue
            m = RE_EXTENDS.match(line)
            if m and info.extends is None:
                info.extends = strip_comment(m.group(1))
                doc = []
                continue
            m = RE_INNER.match(line)
            if m:
                inner_name = m.group(1)
                info.symbols.append(Symbol("class", inner_name, i, path, info.class_name, doc=" ".join(doc)))
                doc = []
                continue
            owner = info.class_name or autoload_name or os.path.basename(path)
        else:
            if inner_name is None:
                doc = []
                continue
            if indent != 1:
                doc = []
                continue
            owner = ((info.class_name or autoload_name or "") + "." if (info.class_name or autoload_name) else "") + inner_name
        body = line.lstrip("\t")
        g = RE_EXPORT_GROUP.match(body)
        if g:
            group = g.group(1)
            doc = []
            continue
        m = RE_FUNC_START.match(line)
        if m:
            # La firma puede ocupar varias lineas: se acumula hasta equilibrar los parentesis.
            sig = m.group(3)
            depth = 1 + sig.count("(") - sig.count(")")
            j = i
            while depth > 0 and j < len(raw):
                nxt = strip_comment(raw[j])
                sig += " " + nxt.strip()
                depth += nxt.count("(") - nxt.count(")")
                j += 1
            skip_until = j
            close = sig.rfind(")")
            args = sig[:close] if close >= 0 else sig
            ret = re.search(r"->\s*([\w\.\[\]]+)", sig[close:]) if close >= 0 else None
            info.symbols.append(Symbol("func", m.group(2), i, path, owner, args=re.sub(r"\s+", " ", args).strip(), ret=ret.group(1) if ret else "", doc=" ".join(doc)))
            doc = []
            continue
        m = RE_SIGNAL.match(body)
        if m:
            info.symbols.append(Symbol("signal", m.group(1), i, path, owner, args=(m.group(2) or ""), doc=" ".join(doc)))
            doc = []
            continue
        m = RE_CONST.match(body)
        if m:
            value = strip_comment(m.group(2))
            depth = sum(value.count(c) for c in "{[(") - sum(value.count(c) for c in "}])")
            j = i
            while depth > 0 and j < len(raw):
                nxt = strip_comment(raw[j])
                value += " " + nxt.strip()
                depth += sum(nxt.count(c) for c in "{[(") - sum(nxt.count(c) for c in "}])")
                j += 1
            skip_until = j
            info.symbols.append(Symbol("const", m.group(1), i, path, owner, default=re.sub(r"\s+", " ", value).strip(), end_line=j, doc=" ".join(doc)))
            doc = []
            continue
        m = RE_ENUM.match(body)
        if m:
            if "}" in m.group(2):
                names = [n.split("=")[0].strip() for n in strip_comment(m.group(2)).split("}")[0].split(",") if n.strip()]
                info.symbols.append(Symbol("enum", m.group(1), i, path, owner, values=names, doc=" ".join(doc)))
            else:
                in_enum = {"name": m.group(1), "line": i, "body": strip_comment(m.group(2)), "doc": " ".join(doc)}
            doc = []
            continue
        m = RE_VAR.match(body)
        if m:
            ann = m.group("ann") or ""
            rng = RE_EXPORT_RANGE.search(ann)
            info.symbols.append(Symbol(
                "var", m.group("name"), i, path, owner,
                type=(m.group("type") or "").strip(), default=strip_comment(m.group("default") or ""),
                exported="@export" in ann, range=(rng.group(1).strip() if rng else ""),
                group=group if "@export" in ann else "", doc=" ".join(doc)))
            doc = []
            continue
        doc = []
    return info


def scan_gdshader(path):
    info = FileInfo(path)
    info.class_name = None
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        info.lines = f.read().split("\n")
    for i, line in enumerate(info.lines, 1):
        m = re.match(r"^uniform\s+([\w\[\]]+)\s+(\w+)\s*(?::\s*([^=;]+))?\s*(?:=\s*([^;]+))?;", line.strip())
        if m:
            info.symbols.append(Symbol("uniform", m.group(2), i, path, os.path.basename(path), type=m.group(1), hint=(m.group(3) or "").strip(), default=(m.group(4) or "").strip()))
        m = re.match(r"^(?:float|vec\d|void|bool|int)\s+(\w+)\s*\(", line.strip())
        if m:
            info.symbols.append(Symbol("func", m.group(1), i, path, os.path.basename(path)))
    return info


def scan_py(path):
    info = FileInfo(path)
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        info.lines = f.read().split("\n")
    for i, line in enumerate(info.lines, 1):
        m = re.match(r"^def\s+(\w+)\s*\(", line)
        if m:
            info.symbols.append(Symbol("func", m.group(1), i, path, os.path.basename(path)))
    return info


def scan_tscn(path):
    info = FileInfo(path)
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        info.lines = f.read().split("\n")
    for i, line in enumerate(info.lines, 1):
        m = re.match(r'^\[node name="([^"]+)" type="([^"]+)"', line)
        if m:
            info.symbols.append(Symbol("node", m.group(1), i, path, os.path.basename(path), type=m.group(2)))
    return info


def autoload_paths():
    """Mapa ruta_relativa -> nombre del autoload, segun project.godot."""
    out = {}
    for name, d in parse_project().get("autoload", {}).items():
        out[d["value"].strip('"').lstrip("*").replace("res://", "")] = name
    return out


def scan_repo():
    files = {}
    autoloads = autoload_paths()
    for d in SCAN_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [x for x in dirnames if not x.startswith(".") and x not in ("__pycache__",)]
            for fn in sorted(filenames):
                if not fn.endswith(SCAN_EXT):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, fn), ROOT).replace(os.sep, "/")
                if fn.endswith(".gd"):
                    files[rel] = scan_gd(rel, autoloads.get(rel))
                elif fn.endswith(".gdshader"):
                    files[rel] = scan_gdshader(rel)
                elif fn.endswith(".py"):
                    files[rel] = scan_py(rel)
                elif fn.endswith(".tscn"):
                    files[rel] = scan_tscn(rel)
                else:
                    files[rel] = FileInfo(rel)
    return files


# --- project.godot -----------------------------------------------------------

def parse_project():
    path = os.path.join(ROOT, "project.godot")
    section = ""
    sections = {}
    current_key = None
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip("\n")
            m = re.match(r"^\[([\w\.]+)\]$", line)
            if m:
                section = m.group(1)
                sections.setdefault(section, {})
                current_key = None
                continue
            m = re.match(r"^([\w\./]+)=(.*)$", line)
            if m and section:
                current_key = m.group(1)
                sections[section][current_key] = {"value": m.group(2), "line": n}
            elif current_key and section and line.strip():
                sections[section][current_key]["value"] += "\n" + line
    return sections


KEYCODES = {65: "A", 68: "D", 87: "W", 83: "S", 74: "J", 75: "K", 73: "I", 76: "L", 81: "Q", 4194325: "Shift", 4194305: "Esc"}


def render_inputs(proj):
    rows = ["| Acción | Zona muerta | Teclas (código físico) | `project.godot` |", "|---|---|---|---|"]
    for key, d in proj.get("input", {}).items():
        dz = re.search(r'"deadzone":\s*([\d\.]+)', d["value"])
        codes = [int(c) for c in re.findall(r'"physical_keycode":(\d+)', d["value"])]
        keys = ", ".join(KEYCODES.get(c, str(c)) for c in codes) or "-"
        rows.append(f"| `{key}` | {dz.group(1) if dz else '-'} | {keys} | línea {d['line']} |")
    return "\n".join(rows)


def render_layers(proj):
    rows = ["| Capa | Valor (máscara) | Nombre | Uso |", "|---|---|---|---|"]
    for key, d in proj.get("layer_names", {}).items():
        m = re.match(r"3d_physics/layer_(\d+)", key)
        if m:
            idx = int(m.group(1))
            rows.append(f"| {idx} | {1 << (idx - 1)} | `{d['value'].strip(chr(34))}` | `Ball.LAYER_*` en `scripts/ball/ball.gd` |")
    return "\n".join(rows)


def render_autoloads(proj):
    rows = ["| Autoload | Script | `project.godot` |", "|---|---|---|"]
    for key, d in proj.get("autoload", {}).items():
        rows.append(f"| `{key}` | `{d['value'].strip(chr(34)).lstrip('*').replace('res://', '')}` | línea {d['line']} |")
    return "\n".join(rows)


# --- Renderizado de bloques AUTO ---------------------------------------------

def esc(text):
    return text.replace("|", "\\|").replace("\n", " ")


def find_class_file(files, class_name):
    for p, fi in files.items():
        if fi.class_name == class_name or getattr(fi, "autoload", None) == class_name:
            return fi
    return None


def _tuning_fields(files, class_name):
    """Campos del autoload Tuning cuyo tipo es class_name (p. ej. 'ball' para BallTuning)."""
    out = []
    for p, fi in files.items():
        if getattr(fi, "autoload", None) != "Tuning":
            continue
        for sym in fi.symbols:
            if sym.kind == "var" and sym.extra.get("type") == class_name:
                out.append(sym.name)
    return out


def _receivers(fi, class_name, tuning_fields):
    """Identificadores de un archivo que contienen una instancia de class_name (anotados, alias := o Tuning.campo)."""
    ids = set()
    ann = re.compile(r"\b(\w+)\s*:\s*" + re.escape(class_name) + r"\b")
    codes = [strip_comment(line) for line in fi.lines]
    for code in codes:
        for m in ann.finditer(code):
            ids.add(m.group(1))
    tf = "|".join(map(re.escape, tuning_fields))
    for _ in range(3):  # propaga alias de un nivel: var cfg := config / var t = Tuning.player
        for code in codes:
            m = re.match(r"^\s*(?:var\s+)?(\w+)\s*(?::\s*\w+\s*)?:?=\s*(.+)$", code)
            if not m:
                continue
            rhs = m.group(2).strip()
            first = re.match(r"^(\w+(?:\.\w+)?)", rhs)
            if first and (first.group(1) in ids or (tf and re.match(r"^Tuning\.(?:" + tf + r")$", first.group(1)))):
                ids.add(m.group(1))
    return ids


def usage_sites(files, owner_file, name, limit=4, class_name=None):
    """Accesos reales al parametro: `receptor.name` donde el receptor es una instancia de class_name
    (anotada, alias o Tuning.campo) y, dentro del archivo que define la clase, el uso directo `name`."""
    tf = _tuning_fields(files, class_name) if class_name else []
    sites = []
    for p, fi in files.items():
        if not p.startswith(("scripts/", "scenes/", "assets/")) or not p.endswith(".gd"):
            continue
        ids = _receivers(fi, class_name, tf) if class_name else set()
        alts = [re.escape(i) for i in sorted(ids)] + ([r"Tuning\.(?:" + "|".join(map(re.escape, tf)) + ")"] if tf else [])
        pat = re.compile(r"(?<![\w\.])(?:" + "|".join(alts) + r")\.\s*" + re.escape(name) + r"\b") if alts else None
        bare = re.compile(r"(?<![\w\.])" + re.escape(name) + r"\b")
        for i, line in enumerate(fi.lines, 1):
            code = strip_comment(line)
            if not code:
                continue
            hit = bool(pat and pat.search(code))
            if not hit and p == owner_file:
                hit = bool(bare.search(code)) and not re.match(r"^\s*(@export\w*(\([^)]*\))?\s+)?var\s+" + re.escape(name) + r"\b", code)
            if hit:
                sites.append(f"{p}:{i}")
    return sites[:limit], len(sites)


def render_params(files, class_name):
    fi = find_class_file(files, class_name)
    if fi is None:
        return f"> ERROR: clase `{class_name}` no encontrada"
    rows = ["| Parámetro | Defecto | Rango / tipo | Definido en | Dónde se usa (accesos reales) | Descripción |", "|---|---|---|---|---|---|"]
    for s in fi.symbols:
        if s.kind != "var" or s.owner != class_name:
            continue
        if not s.extra.get("exported") and fi.class_name != class_name:
            continue
        sites, total = usage_sites(files, fi.path, s.name, class_name=class_name)
        refs = ", ".join(f"`{x}`" for x in sites) + (f" (+{total - len(sites)})" if total > len(sites) else "") if sites else ("**sin uso**" if s.extra.get("exported") else "—")
        rng = s.extra.get("range") or s.extra.get("type") or ""
        grp = f" ({s.extra['group']})" if s.extra.get("group") else ""
        rows.append(f"| `{s.name}` | `{esc(s.extra.get('default') or '—')}` | {esc(rng)} | `{fi.path}:{s.line}` | {esc(refs)} | {esc(s.extra.get('doc') or '')}{esc(grp)} |")
    return "\n".join(rows)


def render_funcs(files, path):
    fi = files.get(path)
    if fi is None:
        return f"> ERROR: archivo `{path}` no encontrado"
    rows = ["| Función | Línea | Qué hace |", "|---|---|---|"]
    for s in fi.symbols:
        if s.kind == "func":
            sig = f"{s.qualified}({esc(s.extra.get('args', ''))})" if path.endswith(".gd") else s.qualified
            rows.append(f"| `{sig}` | {s.line} | {esc((s.extra.get('doc') or '')[:140])} |")
    return "\n".join(rows)


def render_consts(files, path):
    fi = files.get(path)
    if fi is None:
        return f"> ERROR: archivo `{path}` no encontrado"
    rows = ["| Constante / enum / uniform | Valor | Línea | Descripción |", "|---|---|---|---|"]
    for s in fi.symbols:
        if s.kind in ("const", "uniform"):
            val = s.extra.get("default") or ""
            if len(val) > 80:
                val = val[:77] + "..."
            rows.append(f"| `{s.qualified}` | `{esc(val)}` | {s.line} | {esc(s.extra.get('doc') or s.extra.get('hint') or '')} |")
        elif s.kind == "enum":
            rows.append(f"| `{s.qualified}` (enum) | `{esc(', '.join(s.extra.get('values', [])))}` | {s.line} | {esc(s.extra.get('doc') or '')} |")
    return "\n".join(rows)


def render_constdef(files, spec):
    """Incrusta el texto exacto de una constante (archivo#NOMBRE), incluso si ocupa varias lineas."""
    path, _, name = spec.partition("#")
    fi = files.get(path)
    if fi is None:
        return f"> ERROR: archivo `{path}` no encontrado"
    for s in fi.symbols:
        if s.kind == "const" and s.name == name:
            end = s.extra.get("end_line", s.line)
            body = "\n".join(fi.lines[s.line - 1:end])
            return f"`{path}:{s.line}`\n\n```gdscript\n{body}\n```"
    return f"> ERROR: constante `{name}` no encontrada en `{path}`"


def render_attrs(files):
    """Atributos (claves de PlayerAttributes) y los lugares del codigo que realmente los consumen."""
    src = "scripts/progression/player_attributes.gd"
    fi = files.get(src)
    if fi is None:
        return f"> ERROR: archivo `{src}` no encontrado"
    rows = ["| Atributo (clave) | Nombre visible | Grupo | Consumido en (código) |", "|---|---|---|---|"]
    for const_name, group in (("FIELD_ATTRIBUTES", "campo"), ("KEEPER_ATTRIBUTES", "arquero")):
        sym = next((x for x in fi.symbols if x.kind == "const" and x.name == const_name), None)
        if sym is None:
            continue
        for key, label in re.findall(r'"(\w+)":\s*"([^"]+)"', "\n".join(fi.lines[sym.line - 1:sym.extra.get("end_line", sym.line)])):
            pat = re.compile(r'\"' + re.escape(key) + r'\"')
            sites = []
            for p, other in files.items():
                if p == src or not p.startswith("scripts/") or not p.endswith(".gd"):
                    continue
                for i, line in enumerate(other.lines, 1):
                    code = strip_comment(line)
                    # Solo cuenta si la linea consulta atributos (evita claves homonimas de diccionarios).
                    if pat.search(code) and ("attributes" in code or ".factor(" in code or ".norm(" in code):
                        sites.append(f"`{p}:{i}`")
            rows.append(f"| `{key}` | {label} | {group} | {', '.join(sites) if sites else '**sin uso todavía**'} |")
    return "\n".join(rows)


def render_signals(files, path):
    fi = files.get(path)
    if fi is None:
        return f"> ERROR: archivo `{path}` no encontrado"
    rows = ["| Señal | Línea | Descripción |", "|---|---|---|"]
    for s in fi.symbols:
        if s.kind == "signal":
            rows.append(f"| `{s.qualified}{esc(s.extra.get('args', ''))}` | {s.line} | {esc(s.extra.get('doc') or '')} |")
    return "\n".join(rows)


def render_tests(files, path):
    fi = files.get(path)
    if fi is None:
        return f"> ERROR: archivo `{path}` no encontrado"
    rows = ["| Prueba | Línea |", "|---|---|"]
    for s in fi.symbols:
        if s.kind == "func" and s.name.startswith("test_"):
            rows.append(f"| `{s.name}` | {s.line} |")
    return "\n".join(rows)


BLOCK_RE = re.compile(r"(<!-- AUTO:(\w+)(?::([^ ]+))? -->\n)(.*?)(<!-- /AUTO -->)", re.S)


def render_block(kind, arg, files, proj):
    if kind == "params":
        return render_params(files, arg)
    if kind == "funcs":
        return render_funcs(files, arg)
    if kind == "consts":
        return render_consts(files, arg)
    if kind == "signals":
        return render_signals(files, arg)
    if kind == "constdef":
        return render_constdef(files, arg)
    if kind == "attrs":
        return render_attrs(files)
    if kind == "tests":
        return render_tests(files, arg)
    if kind == "inputs":
        return render_inputs(proj)
    if kind == "layers":
        return render_layers(proj)
    if kind == "autoloads":
        return render_autoloads(proj)
    if kind == "verified":
        return today()
    return f"> ERROR: tipo de bloque desconocido `{kind}`"


def doc_files():
    out = []
    for dirpath, _, filenames in os.walk(DOCS):
        for fn in sorted(filenames):
            if fn.endswith(".md"):
                out.append(os.path.join(dirpath, fn))
    return out


def process_md(path, files, proj, write):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    changed = []

    def repl(m):
        new = render_block(m.group(2), m.group(3), files, proj).rstrip("\n") + "\n"
        if new != m.group(4):
            changed.append(f"{m.group(2)}:{m.group(3) or ''}")
        return m.group(1) + new + m.group(5)

    new_text = BLOCK_RE.sub(repl, text)
    if write and new_text != text:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_text)
    return changed


# --- CODE_MAP.json -------------------------------------------------------------

def load_map():
    with open(CODE_MAP, encoding="utf-8") as f:
        return json.load(f)


def resolve_symbol(files, qualified, hint_file=None):
    """Devuelve (Symbol, FileInfo) para 'Clase.miembro' (o 'Clase.Interna.miembro')."""
    candidates = [hint_file] if hint_file else list(files)
    for p in candidates:
        fi = files.get(p)
        if fi is None:
            continue
        s = fi.find(qualified)
        if s is not None:
            return s, fi
    return None, None


def sync_map(files, write):
    data = load_map()
    problems = []
    for e in data["entries"]:
        for sym in e.get("symbols", []):
            s, _ = resolve_symbol(files, sym["name"], sym["file"])
            if s is None:
                problems.append(f"{e['id']}: simbolo no encontrado {sym['name']} en {sym['file']}")
                continue
            if sym.get("line") != s.line or sym.get("kind") != s.kind:
                if write:
                    sym["line"] = s.line
                    sym["kind"] = s.kind
                else:
                    problems.append(f"{e['id']}: desfase en {sym['name']} (json {sym.get('line')} vs codigo {s.line})")
        for par in e.get("parameters", []):
            s, _ = resolve_symbol(files, par["name"], par["file"])
            if s is None:
                problems.append(f"{e['id']}: parametro no encontrado {par['name']} en {par['file']}")
                continue
            default = s.extra.get("default", "")
            if par.get("default") != default or par.get("line") != s.line:
                if write:
                    par["default"] = default
                    par["line"] = s.line
                else:
                    problems.append(f"{e['id']}: desfase en parametro {par['name']} (json {par.get('default')}@{par.get('line')} vs codigo {default}@{s.line})")
        if write:
            e["last_verified"] = today()
    if write:
        data["last_verified"] = today()
        with open(CODE_MAP, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    return data, problems



RE_TEST_TOKEN = re.compile(r"^test_\w+$")
RE_MEMBER_TOKEN = re.compile(r"^([A-Z]\w+)\.(\w+)(?:\(\))?$")


def known_symbols(files):
    """Conjuntos para validar citas en el texto: nombres de pruebas, clases y miembros por clase."""
    tests = set()
    members = {}
    for p, fi in files.items():
        for s in fi.symbols:
            if s.kind == "func" and s.name.startswith("test_") and p.startswith("tests/"):
                tests.add(s.name)
        if p.startswith("tests/") and os.path.basename(p).startswith("test_") and p.endswith(".gd"):
            tests.add(os.path.splitext(os.path.basename(p))[0])   # `test_ball_physics` = la suite
        owner = fi.class_name or getattr(fi, "autoload", None)
        if owner:
            members.setdefault(owner, set())
            for s in fi.symbols:
                if s.kind == "enum":
                    # un enum expone su nombre y cada uno de sus valores
                    members[owner].add(s.name)
                    for v in s.extra.get("values", []) or []:
                        members[owner].add(v)
                elif s.kind == "class":
                    members[owner].add(s.name)
                else:
                    # miembros de la clase propietaria (o de una interna: se cuentan con el nombre simple)
                    members[owner].add(s.name)
    return tests, members


# --- Comandos --------------------------------------------------------------------

def cmd_sync():
    files = scan_repo()
    proj = parse_project()
    changed_total = 0
    for p in doc_files():
        ch = process_md(p, files, proj, write=True)
        if ch:
            changed_total += len(ch)
            print(f"  actualizado {os.path.relpath(p, ROOT)}: {len(ch)} bloque(s) ({', '.join(ch[:4])}{'...' if len(ch) > 4 else ''})")
    _, problems = sync_map(files, write=True)
    for pr in problems:
        print("  ! " + pr)
    print(f"sync: {changed_total} bloque(s) AUTO regenerados, CODE_MAP.json actualizado ({today()}), {len(problems)} problema(s)")
    return 1 if problems else 0


def cmd_check():
    files = scan_repo()
    proj = parse_project()
    errors = []
    warnings = []
    # 1. JSON valido
    try:
        data = load_map()
    except Exception as ex:  # noqa: BLE001
        print(f"ERROR: CODE_MAP.json no se puede parsear: {ex}")
        return 1
    ids = [e["id"] for e in data["entries"]]
    if len(ids) != len(set(ids)):
        errors.append("CODE_MAP.json: ids duplicados")
    required = {"id", "system", "description", "keywords", "files", "symbols", "parameters", "dependencies", "documentation", "last_verified"}
    for e in data["entries"]:
        miss = required - set(e)
        if miss:
            errors.append(f"{e.get('id')}: faltan campos {sorted(miss)}")
        for fp in e.get("files", []) + [e.get("documentation", "")]:
            if fp and not os.path.exists(os.path.join(ROOT, fp)):
                errors.append(f"{e['id']}: ruta inexistente {fp}")
        for dep in e.get("dependencies", []):
            if dep not in {x["system"] for x in data["entries"]} and dep not in ("GODOT", "TRIPO"):
                warnings.append(f"{e['id']}: dependencia '{dep}' no es un sistema indexado")
    # 2. simbolos y parametros
    _, problems = sync_map(files, write=False)
    errors += problems
    known_tests, known_members = known_symbols(files)
    # 3. bloques AUTO
    for p in doc_files():
        ch = process_md(p, files, proj, write=False)
        for c in ch:
            errors.append(f"{os.path.relpath(p, ROOT)}: bloque AUTO desactualizado ({c}) -> ejecutar `sync`")
        with open(p, encoding="utf-8") as f:
            text = f.read()
        if "ERROR:" in "".join(m.group(4) for m in BLOCK_RE.finditer(text)):
            errors.append(f"{os.path.relpath(p, ROOT)}: un bloque AUTO contiene un ERROR (clase/archivo inexistente)")
        # 4. rutas citadas en el texto
        for token in re.findall(r"`([^`\n]+)`", text):
            t = token.split(":")[0] if re.match(r"^[\w\-./]+:\d+(-\d+)?$", token) else token
            if RE_PATH_TOKEN.match(t) and not os.path.exists(os.path.join(ROOT, t)):
                errors.append(f"{os.path.relpath(p, ROOT)}: ruta citada inexistente `{token}`")
            if RE_TEST_TOKEN.match(token) and token not in known_tests:
                errors.append(f"{os.path.relpath(p, ROOT)}: prueba citada inexistente `{token}`")
            mm = RE_MEMBER_TOKEN.match(token)
            if mm and mm.group(1) in known_members and mm.group(2) != "new" and mm.group(2) not in known_members[mm.group(1)]:
                errors.append(f"{os.path.relpath(p, ROOT)}: miembro citado inexistente `{token}`")
    # 5. cobertura: cada .gd de scripts/ debe estar en alguna entrada
    indexed = {fp for e in data["entries"] for fp in e.get("files", [])}
    for p in sorted(files):
        if p.startswith("scripts/") and p.endswith(".gd") and p not in indexed:
            warnings.append(f"sin indexar en CODE_MAP.json: {p}")
    for w in warnings:
        print("  aviso: " + w)
    for er in errors:
        print("  ERROR: " + er)
    print(f"check: {len(data['entries'])} entradas, {len(errors)} error(es), {len(warnings)} aviso(s)")
    return 1 if errors else 0


def norm(text):
    table = str.maketrans("áéíóúüñÁÉÍÓÚÜÑ", "aeiouunAEIOUUN")
    return text.translate(table).lower()


def cmd_find(terms):
    data = load_map()
    toks = [norm(t) for t in " ".join(terms).split() if len(t) > 1]
    if not toks:
        print("uso: docs_index.py find <terminos>")
        return 2
    scored = []
    for e in data["entries"]:
        kw = [norm(k) for k in e["keywords"]]
        hay_text = norm(" ".join([e["id"], e["system"], e["description"]] + [s["name"] for s in e["symbols"]] + [p["name"] for p in e["parameters"]]))
        score = 0
        for t in toks:
            if any(t == k for k in kw):
                score += 5
            elif any(t in k or k in t for k in kw if len(k) > 3):
                score += 3
            if t in hay_text:
                score += 1
        if score:
            scored.append((score, e))
    scored.sort(key=lambda x: -x[0])
    if not scored:
        print("sin coincidencias; revisar docs/technical-index/INDEX.md")
        return 1
    for score, e in scored[:4]:
        print(f"[{score:2d}] {e['id']}  ({e['system']})  -> {e['documentation']}")
        print(f"      {e['description']}")
        print(f"      archivos: {', '.join(e['files'])}")
        sy = [s["name"] + ":" + str(s.get("line", "?")) for s in e["symbols"][:8]]
        if sy:
            print(f"      simbolos: {', '.join(sy)}")
        pa = [p["name"] + "=" + str(p.get("default", "?")) for p in e["parameters"][:8]]
        if pa:
            print(f"      parametros: {', '.join(pa)}")
    return 0


def cmd_where(name):
    files = scan_repo()
    hits = []
    for p, fi in files.items():
        for s in fi.symbols:
            if s.qualified == name or (s.name == name and "." not in name):
                hits.append((p, s))
    if not hits:
        print(f"'{name}' no encontrado")
        return 1
    for p, s in hits:
        print(f"{s.kind:7s} {s.qualified}  {p}:{s.line}  " + (f"= {s.extra.get('default')}" if s.extra.get("default") else ""))
        if s.kind in ("var", "const"):
            sites, total = usage_sites(files, p, s.name, limit=12, class_name=(files[p].class_name or getattr(files[p], "autoload", None)))
            print(f"        accesos ({total}): {', '.join(sites)}")
    return 0


def cmd_stats():
    files = scan_repo()
    kinds = {}
    for fi in files.values():
        for s in fi.symbols:
            kinds[s.kind] = kinds.get(s.kind, 0) + 1
    print(f"archivos escaneados: {len(files)}; simbolos: {sum(kinds.values())} {kinds}")
    return 0


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd = argv[1]
    if cmd == "sync":
        return cmd_sync()
    if cmd == "check":
        return cmd_check()
    if cmd == "find":
        return cmd_find(argv[2:])
    if cmd == "where" and len(argv) > 2:
        return cmd_where(argv[2])
    if cmd == "stats":
        return cmd_stats()
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
