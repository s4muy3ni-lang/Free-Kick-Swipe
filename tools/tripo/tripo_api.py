#!/usr/bin/env python3
"""Cliente minimo de la API oficial de Tripo3D (v3) para el proyecto Futbol5.

Reglas del proyecto (CLAUDE.md): la clave NUNCA se escribe en el repositorio, en el chat ni en registros; las
operaciones de pago exigen comprobar el saldo antes, no pasar del tope pedido y anotar el gasto en
docs/tripo/ledger.jsonl.

Clave: variable de entorno TRIPO_API_KEY (configurada en los ajustes del entorno, no en el codigo). Si el entorno
inyecta la credencial por el proxy (secreto de red), se puede llamar sin la variable.

Documentacion usada (comprobada 2026-10-28): https://developers.tripo3d.com/en/docs/introduction
  GET  /account/balance            -> data.balance, data.frozen
  GET  /account/usage              -> data[]: task_id, type, credits_consumed, created_at
  GET  /tasks/{task_id}            -> data.status (queued|running|success|failed|cancelled), data.output.model_url
  POST /animations/retarget        -> input (task_id del modelo riggeado), animation|animations (<=5 presets),
                                      out_format (glb|fbx), animate_in_place, export_with_geometry

Uso:
  python3 tools/tripo/tripo_api.py balance
  python3 tools/tripo/tripo_api.py usage [--type rig]
  python3 tools/tripo/tripo_api.py task <task_id>
  python3 tools/tripo/tripo_api.py retarget --rig-task <task_id> --presets dribble,crossover_dribble \\
      --max-credits 20 [--per-preset 10] [--yes]
Sin --yes, retarget solo muestra lo que haria y el coste estimado (no gasta nada).

ESTADO: escrito contra la documentacion oficial; NO probado contra la cuenta (en la sesion en que se escribio no
habia clave). La primera ejecucion real debe ser `balance` y `usage`, que no gastan creditos.
"""
import argparse
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "https://openapi.tripo3d.com/v3"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEDGER = os.path.join(ROOT, "docs", "tripo", "ledger.jsonl")
OUT_DIR = os.path.join(ROOT, "assets", "animations", "source", "tripo")


def _headers():
    h = {"Content-Type": "application/json", "Accept": "application/json"}
    key = os.environ.get("TRIPO_API_KEY", "").strip()
    if key:
        h["Authorization"] = "Bearer " + key
    return h


def _call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers=_headers())
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        # Nunca se muestran cabeceras (llevan la clave); solo el codigo y el cuerpo de error del servidor.
        body = e.read().decode(errors="replace")[:500]
        sys.exit("Tripo respondio %d en %s %s: %s" % (e.code, method, path, body))


def balance():
    d = _call("GET", "/account/balance").get("data", {})
    return float(d.get("balance", 0.0)), float(d.get("frozen", 0.0))


def cmd_balance(_a):
    b, f = balance()
    print("saldo %.2f creditos (congelados %.2f)" % (b, f))


def cmd_usage(a):
    d = _call("GET", "/account/usage").get("data", [])
    for t in d:
        if a.type and str(t.get("type", "")) != a.type:
            continue
        print("%s  %-20s %8s creditos  %s" % (t.get("created_at", "?"), t.get("type", "?"), t.get("credits_consumed", "?"), t.get("task_id", "?")))


def task(task_id):
    return _call("GET", "/tasks/" + task_id).get("data", {})


def cmd_task(a):
    t = task(a.task_id)
    out = t.get("output", {}) or {}
    print(json.dumps({k: t.get(k) for k in ("task_id", "type", "status", "progress", "credits_consumed", "created_at", "completed_at", "error_message")}, ensure_ascii=False))
    if out:
        print("salidas:", ", ".join(sorted(out.keys())))


def _ledger(entry):
    os.makedirs(os.path.dirname(LEDGER), exist_ok=True)
    with open(LEDGER, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def cmd_retarget(a):
    presets = [p.strip() for p in a.presets.split(",") if p.strip()]
    if not presets or len(presets) > 5:
        sys.exit("entre 1 y 5 presets por peticion (limite de la API)")
    ids = [p if p.startswith("preset:") else "preset:biped:" + p for p in presets]
    estimate = a.per_preset * len(ids)
    b0, frozen = balance()
    print("retarget de %s sobre %s (%s, en el sitio=%s)" % (ids, a.rig_task, a.format, not a.root_motion))
    print("coste estimado %.0f creditos (%.0f por preset, segun el registro del proyecto y el ejemplo oficial); saldo %.2f" % (estimate, a.per_preset, b0))
    if estimate > a.max_credits:
        sys.exit("el coste estimado supera el tope --max-credits %.0f: no se envia nada" % a.max_credits)
    if b0 - estimate < a.reserve:
        sys.exit("el saldo quedaria por debajo de la reserva de %.0f creditos: no se envia nada" % a.reserve)
    if not a.yes:
        print("(simulacion: anade --yes para enviar la tarea; no se ha gastado nada)")
        return
    body = {"input": a.rig_task, "animations": ids, "out_format": a.format, "animate_in_place": not a.root_motion}
    r = _call("POST", "/animations/retarget", body)
    tid = r.get("data", {}).get("task_id")
    if not tid:
        sys.exit("respuesta sin task_id: %s" % json.dumps(r)[:300])
    print("tarea", tid)
    t = {}
    for _ in range(120):
        t = task(tid)
        if t.get("status") in ("success", "failed", "cancelled"):
            break
        time.sleep(5)
    b1, _f = balance()
    spent = float(t.get("credits_consumed") or (b0 - b1))
    _ledger({"ts": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"), "task": "retarget %s %s %s" % (a.rig_task, ids, a.format),
             "task_id": tid, "result": t.get("status"), "balance_before": b0, "balance_after": b1, "spent": spent,
             "notes": "estimado %.0f" % estimate})
    print("estado %s; gastado %.2f; saldo %.2f -> %.2f (anotado en docs/tripo/ledger.jsonl)" % (t.get("status"), spent, b0, b1))
    url = (t.get("output") or {}).get("model_url")
    if t.get("status") == "success" and url:
        os.makedirs(OUT_DIR, exist_ok=True)
        dest = os.path.join(OUT_DIR, "retarget_%s.%s" % ("_".join(p.split(":")[-1] for p in ids), a.format))
        with urllib.request.urlopen(url, timeout=120) as r2, open(dest, "wb") as f:
            f.write(r2.read())
        print("descargado en", os.path.relpath(dest, ROOT))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("balance").set_defaults(fn=cmd_balance)
    u = sub.add_parser("usage")
    u.add_argument("--type", default="")
    u.set_defaults(fn=cmd_usage)
    t = sub.add_parser("task")
    t.add_argument("task_id")
    t.set_defaults(fn=cmd_task)
    r = sub.add_parser("retarget")
    r.add_argument("--rig-task", required=True)
    r.add_argument("--presets", required=True)
    r.add_argument("--format", default="glb", choices=["glb", "fbx"])
    r.add_argument("--root-motion", action="store_true", help="exportar con desplazamiento (por defecto en el sitio)")
    r.add_argument("--max-credits", type=float, required=True)
    r.add_argument("--per-preset", type=float, default=10.0)
    r.add_argument("--reserve", type=float, default=200.0)
    r.add_argument("--yes", action="store_true")
    r.set_defaults(fn=cmd_retarget)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
