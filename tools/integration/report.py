#!/usr/bin/env python3
"""Cruza evidencia de ejecucion con el inventario original sin convertir registro en conexion."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / 'docs/integration'


def main():
    audit = json.loads((REPORT / 'runtime_audit.json').read_text())
    by_id = {r['id']: r for r in audit['rows']}
    with (ROOT / 'docs/transferencia_integracion_completa/INVENTARIO_ANIMACIONES.csv').open() as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fields = reader.fieldnames
    extra = ['registrado_comprobado', 'invocado_comprobado', 'pose_muestreada', 'espejo_invocado',
             'rol_indexado', 'verificacion_visual_individual', 'verificado_android', 'errores_ejecucion']
    for row in rows:
        runtime = by_id.get(row['id_juego'], {})
        mirror = by_id.get(row['id_espejo'], {})
        for column, key in [('registrado_comprobado', 'registered'), ('invocado_comprobado', 'invoked'),
                            ('pose_muestreada', 'pose_sampled'), ('rol_indexado', 'role_indexed')]:
            row[column] = str(runtime.get(key, False)).lower()
        row['espejo_invocado'] = str(mirror.get('invoked', False)).lower()
        row['verificacion_visual_individual'] = 'no_comprobada_en_esta_sesion'
        row['verificado_android'] = 'no'
        row['errores_ejecucion'] = '; '.join(runtime.get('errors', ['sin evidencia']) if not runtime else runtime['errors'])
    with (REPORT / 'estado_individual.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields + extra)
        writer.writeheader()
        writer.writerows(rows)
    pending = [r for r in rows if r['estado_conexion'] != 'si']
    with (REPORT / 'conexiones_pendientes.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields + extra)
        writer.writeheader()
        writer.writerows(pending)
    print(f'{len(rows)} tramos, {len(set(r["indice"] for r in rows))} fuentes, {len(pending)} conexiones pendientes; {audit["tested"]} variantes muestreadas')


if __name__ == '__main__':
    main()
