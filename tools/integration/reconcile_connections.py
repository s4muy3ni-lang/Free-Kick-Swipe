#!/usr/bin/env python3
"""Estado individual de la cohorte pendiente. Verificado exige el log ejecutado del consumidor, no solo el catalogo."""
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/integration/continuacion'
GAIT = {'loco_sprint', 'loco_walk', 'loco_jog', 'loco_side', 'gk_loco',
        'dribble_fast', 'dribble_run', 'dribble_jog', 'dribble_sprint'}
TRANSITIONS = {'start', 'step_stand', 'run_change', 'turn_stop'}
FREE_KICKS = {'jn_setpiece_pass_3330', 'jn_setpiece_pass_3342', 'jn_setpiece_pass_3346',
              'jn_setpiece_shot_3354', 'jn_setpiece_shot_3856'}


def successful(log):
    path = OUT / 'pruebas' / log
    text = path.read_text() if path.exists() else ''
    return bool(re.search(r'Resumen: \d+ pruebas, 0 fallidas', text)) and 'SCRIPT ERROR' not in text


def route_for(row, environment):
    clip, role = row['id_juego'], row['accion_rol']
    if clip in environment:
        route = environment[clip]
        return ('MatchPresentation.request', route['actor'] + '/' + route['context'],
                route['reason'], 'conexiones.log')
    if role in GAIT:
        return ('FootballerVisual.AnimationTree', 'locomotion/' + role,
                'Bucle en mezcla frontal, de conduccion o direccional segun velocidad y rumbo medidos; arquero solo en keeper_mode.', 'marcha.log')
    if role == 'gk_turn':
        return ('Goalkeeper.start_orientation_turn', 'keeper/orientation',
                'Balon a 6 m o mas; sin amenaza rapida; cambio de rumbo compatible; raiz dentro de cancha; interrumpible por tiro real.', 'conexiones.log')
    if role in TRANSITIONS:
        return ('PlayerActions.request_locomotion_transition', 'locomotion/' + role,
                'Sin posesion, pase entrante ni golpeo; velocidad de entrada, rumbo, destino y espacio compatibles; via ActionArbiter.', 'conexiones.log')
    if clip in FREE_KICKS:
        return ('SetPiece.recovered_free_kicks', 'set_piece/free_kick_' + ('shot' if 'shot' in clip else 'pass'),
                'Tiro libre con carrerilla libre; contacto barrido 3D real; no se rehabilita automaticamente en corners ni penales.', 'tiros_libres.log')
    if role == 'kick_cross':
        return ('BallHandler.plan_clip_kick', 'kick/cross',
                'Pelota junto al pie lateral, plan fisico valido; variante opcional no evita filtros ni habilita otro tipo de golpeo.', 'centros.log')
    if role == 'throw_prep':
        return ('SetPiece._orient_throw', 'set_piece/throw_orientation',
                'Cambio de orientacion compatible antes del lanzamiento; pelota sostenida durante el giro; despues saque real.', 'banda.log')
    if clip == 'jn_nis_misc_0450':
        return ('Ball._on_body_entered -> Footballer.on_ball_impact', 'contact/ball_face',
                'Colision real con pelota de partido a altura de cara y por delante; sin golpeo en curso; arbitraje BODY.', 'pelotazo.log')
    return None


def blocker(row):
    role, name = row['accion_rol'], row['nombre_ucs']
    if role in {'receive', 'receive_turn', 'control_stand', 'ball_sole'}:
        return 'Falta confirmar parte e instante de contacto contra el balon real; no se habilita un perfil pendiente por cambiar su etiqueta. ' + row['motivo_estado']
    if role == 'setpiece_miss':
        return 'La suelta medida ocurre al inicio y sin velocidad de lanzamiento: falta un evento de suelta confirmado para este clip, no se fabrica un saque.'
    if role == 'kick_flick':
        return 'Falta planificar y comprobar el vuelo entre los dos toques del sombrero; el sistema de movimiento con balon actual enlaza toques rasos.'
    if any(x in name for x in ['_P0', '_P1', '_ANDY', '_CHRIS']):
        return 'Interaccion, caida o dolor: faltan alineacion y sincronizacion de participantes o correspondencia de postura; cuatro poses no prueban el contacto.'
    if any(x in name for x in ['BOTTLE', 'PICK', 'PLACE', 'POSITION_BALL', 'CATCH', 'THROWS', 'BOARD', 'BAR']):
        return 'Falta implementar y comprobar el objeto o participante y su sincronizacion de contacto; no basta una pose sin el objeto.'
    if any(x in name for x in ['INJURED', 'INURED', 'KNEE', 'FOOT', 'LYING', 'LIE_', 'SLIDE']):
        return 'Falta conectar la postura inicial/final y la recuperacion con un contacto, caida o estado de lesion real; no se aplica como festejo generico.'
    return 'Funcion o entrada/salida no suficientemente confirmadas; inspeccion de poses disponible. ' + row['motivo_estado']


def main():
    with (ROOT / 'docs/integration/conexiones_pendientes.csv').open() as f:
        original = list(csv.DictReader(f))
    environment = json.loads((ROOT / 'resources/animation/environment_routes.json').read_text())
    records = {}
    for row in original:
        clip = row['id_juego']
        item = {'id': clip, 'source': row['indice'], 'name': row['nombre_ucs'],
                'role': row['accion_rol'], 'historical_connection': row['estado_conexion'],
                'original_reason': row['motivo_estado'], 'duration_seconds': float(row['duracion_s']),
                'registered': row['registrado_comprobado'] == 'true'}
        route = route_for(row, environment)
        if route:
            consumer, action, condition, log = route
            verified = successful(log)
            item.update(consumer=consumer, action=action, condition=condition,
                        invocation_verified=verified,
                        status='connected_invocation_verified' if verified else 'implemented_unverified',
                        evidence='docs/integration/continuacion/pruebas/' + log)
        else:
            item.update(status='pending', invocation_verified=False, blocking_reason=blocker(row))
        if row['accion_rol'] == 'nis_misc':
            # Orden fijo de las 107 hojas generadas y revisadas en esta continuacion.
            nis = [r['id_juego'] for r in original if r['accion_rol'] == 'nis_misc']
            index = nis.index(clip)
            item['pose_sheet'] = 'docs/integration/continuacion/visual/page_%02d.png' % (index // 8)
            item['pose_sheet_row'] = index % 8 + 1
            item['visual_scope'] = '4 poses del clip sobre humanoide canonico; no certifica interacciones ni todos los fotogramas'
        records[clip] = item
    verified = sum(r['invocation_verified'] for r in records.values())
    summary = {'cohort': len(records), 'connected_invocation_verified': verified,
               'remaining': len(records) - verified, 'complete': verified == len(records)}
    data = {'version': 1, 'base_commit': '0b46c10', 'summary': summary, 'clips': records}
    (ROOT / 'resources/animation/connection_routes.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    fields = ['id', 'source', 'name', 'role', 'duration_seconds', 'historical_connection', 'registered',
              'status', 'consumer', 'action', 'condition', 'invocation_verified', 'evidence',
              'blocking_reason', 'pose_sheet', 'pose_sheet_row', 'visual_scope', 'original_reason']
    for filename, rows in [('estado_338.csv', list(records.values())),
                           ('pendientes_actuales.csv', [r for r in records.values() if not r['invocation_verified']])]:
        with (OUT / filename).open('w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
    hashes = {str(p.relative_to(OUT)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted((OUT / 'pruebas').glob('*.log'))}
    (OUT / 'evidencia_sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
    print(summary)


if __name__ == '__main__':
    main()
