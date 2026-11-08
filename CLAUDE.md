# Fútbol 5 — instrucciones para Claude Code

Juego de fútbol 5 / futsal para Android: Godot 4.7.2, GDScript, renderer GL Compatibility, física Jolt a 60 Hz.

## Antes de tocar nada: usar el índice técnico

> Atajo de una página (dónde está cada cosa, pruebas, APK, reglas): [`docs/START_HERE.md`](docs/START_HERE.md).
> **Estado actual, fases y metodología de trabajo (leer primero en un chat nuevo):** [`docs/ESTADO_Y_METODOLOGIA.md`](docs/ESTADO_Y_METODOLOGIA.md).

1. Leer [`docs/technical-index/INDEX.md`](docs/technical-index/INDEX.md) (tabla de sistemas → archivos, símbolos, parámetros y fichas).
2. Buscar sin leer el repositorio: `python3 tools/docs_index.py find <palabras de la petición>` (acepta español e inglés).
3. Abrir **solo** la ficha del sistema (`docs/technical-index/SYSTEMS/<SISTEMA>.md`) y confirmar el símbolo: `python3 tools/docs_index.py where Clase.miembro`.
4. Leer únicamente el código inmediato que se va a cambiar; ampliar a otros sistemas solo si la ficha lo indica en «Depende de» o «Dependencias».
5. Hacer el cambio mínimo, ejecutar la prueba del sistema (`tools/run_tests.sh <filtro>`; suite completa: `tools/run_tests.sh`).
6. **Actualizar la documentación en el mismo cambio:** `python3 tools/docs_index.py sync`, ajustar a mano lo que sea criterio (responsabilidad, dependencias, riesgos), `python3 tools/docs_index.py check` (debe terminar sin errores) y una entrada en `docs/technical-index/CHANGELOG.md` si el cambio es funcional o estructural.

El procedimiento completo está al final de `INDEX.md`. Si el índice y el código no coinciden, **manda el código**: corregir la ficha, no inventar.

## Reglas del proyecto

- **No inventar resultados.** No registrar como aprobada una prueba que no se ejecutó; informar fallos con la salida real. `tools/run_tests.sh` devuelve error si hay `SCRIPT ERROR`.
- **No cambiar la mecánica de juego** salvo que la tarea lo pida; los ajustes de balance viven en los valores por defecto de las clases `*Tuning` (ver [`SYSTEMS/TUNING.md`](docs/technical-index/SYSTEMS/TUNING.md)) y los números fijos del código están listados en `ARCHITECTURE.md`.
- **Secretos:** nunca escribir la clave de Tripo3D ni claves de firma Android en el repositorio, en el chat ni en registros. Los secretos de CI van en GitHub Secrets.
- **Tripo3D:** las operaciones de pago (generar, rig, retarget) requieren comprobar el coste antes, no superar el presupuesto (reserva ~200 créditos) y anotar cada gasto en `docs/tripo/ledger.jsonl`. Nunca forman parte de tareas de documentación.
- **Git (actualización 2026-11-07):** la reforma a tiros libres y penales (prioridad actual) se hace en la rama `reforma-tiros-penales`; estado en [`docs/reforma/ESTADO_REFORMA.md`](docs/reforma/ESTADO_REFORMA.md) y cómo continuar en [`docs/reforma/CONTINUAR_REFORMA.md`](docs/reforma/CONTINUAR_REFORMA.md). No modificar `integracion-openai` ni `respaldo-f3`. La guía maestra de animaciones del partido (en pausa) quedó en `integracion-openai`; cómo continuar: [`docs/integration/CONTINUAR_GUIA_ANIMACIONES.md`](docs/integration/CONTINUAR_GUIA_ANIMACIONES.md). Regla anterior: trabajar en la rama `respaldo-f3` (el usuario lo pidió: todo se guarda ahí y se sube a la rama principal `ccr-a6c53cd2-uoxpk0`, la rama por defecto en GitHub, solo al terminar); no abrir PR salvo petición explícita. Estado, fases y metodología acordada: [`docs/ESTADO_Y_METODOLOGIA.md`](docs/ESTADO_Y_METODOLOGIA.md).

## Convenciones de código (resumen; detalle en `ARCHITECTURE.md`)

- Sangría con tabuladores; `class_name` en cada clase reutilizable; tipado explícito; comentarios `##` y texto de interfaz en español; identificadores en inglés.
- Ejes: X = largo (arcos en x = ±25 en la cancha de fútbol 7 de 50 × 30 del juego; ±20 en la de futsal 40 × 20 de las pruebas de mecánica), Z = ancho, Y = arriba. El equipo 0 ataca +X. `yaw = 0` mira a −Z.
- La pelota solo cambia de velocidad por impulsos (`Ball.kick`) y por su integración física; nunca se fija su posición para «conducirla».
- Los atributos de jugador escalan parámetros dentro de límites (`PlayerAttributes.factor/norm`), no sustituyen la física.
