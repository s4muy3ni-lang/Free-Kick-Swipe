# PROGRESSION — Atributos de jugador (PARCIAL: sin progresión, editor ni guardado)

## Identificación

- **Responsabilidad exacta (lo implementado):** `PlayerAttributes` (`Resource`): 23 atributos de campo y 8 de arquero en escala 1–100, separados de la identidad y la apariencia. Los atributos **no sustituyen la física**: escalan parámetros, tolerancias y errores dentro de límites (`factor(clave, spread)` → 1.0 con valor 50; `norm(clave)` → 0..1).
- **Estado real: parcial.** No hay experiencia, niveles, entrenamiento, recompensas, estadísticas por jugador, editor de personaje (`scenes/character_creator/` está vacío), guardado/carga de jugadores ni economía. No hay monetización con dinero real ni existe código para ella.
- **Última verificación:** <!-- AUTO:verified -->
2026-11-12
<!-- /AUTO -->

## Archivos responsables

| Ruta | Función | Símbolos relevantes | Dependencias directas |
|---|---|---|---|
| `scripts/progression/player_attributes.gd` | Clase `PlayerAttributes`: valores, claves válidas, `factor`, `norm`, `overall`, serialización validada (`to_dict`/`from_dict`) | `PlayerAttributes.factor`, `PlayerAttributes.norm`, `PlayerAttributes.set_value`, `PlayerAttributes.from_dict`, `PlayerAttributes.FIELD_ATTRIBUTES`, `PlayerAttributes.KEEPER_ATTRIBUTES` | — |
| `scripts/gameplay/match_scene.gd` | Crea los atributos de cada futbolista: `reset_to(55)` | `MatchScene._make_footballer` | `PlayerAttributes` |
| `scripts/player/locomotion.gd`, `ball_handler.gd`, `scripts/assistance/*` | Consumen los atributos | ver tabla de uso | `PlayerAttributes` |

## Atributos y su uso real

<!-- AUTO:attrs -->
| Atributo (clave) | Nombre visible | Grupo | Consumido en (código) |
|---|---|---|---|
| `speed` | Velocidad | campo | `scripts/player/locomotion.gd:57`, `scripts/player/locomotion.gd:60` |
| `acceleration` | Aceleración | campo | `scripts/player/ball_handler.gd:2110`, `scripts/player/ball_handler.gd:2111`, `scripts/player/ball_handler.gd:2456`, `scripts/player/ball_handler.gd:2550`, `scripts/player/ball_turn.gd:182`, `scripts/player/ball_turn.gd:219`, `scripts/player/ball_turn.gd:301`, `scripts/player/drag_back.gd:197`, `scripts/player/drag_back.gd:293`, `scripts/player/locomotion.gd:73`, `scripts/player/locomotion.gd:189` |
| `stamina` | Resistencia | campo | `scripts/player/locomotion.gd:79`, `scripts/player/locomotion.gd:165`, `scripts/player/locomotion.gd:192` |
| `balance` | Equilibrio | campo | `scripts/assistance/kick_model.gd:85`, `scripts/player/ball_handler.gd:3206`, `scripts/player/player_actions.gd:494`, `scripts/player/player_actions.gd:495` |
| `agility` | Agilidad | campo | `scripts/player/ball_handler.gd:654`, `scripts/player/ball_handler.gd:2114`, `scripts/player/ball_turn.gd:191`, `scripts/player/ball_turn.gd:218`, `scripts/player/drag_back.gd:198`, `scripts/player/drag_back.gd:292`, `scripts/player/locomotion.gd:74`, `scripts/player/locomotion.gd:190` |
| `ball_control` | Control de balón | campo | `scripts/player/ball_handler.gd:1652`, `scripts/player/ball_handler.gd:3162`, `scripts/player/ball_handler.gd:3166`, `scripts/player/ball_handler.gd:3180`, `scripts/player/json_receive.gd:687` |
| `ball_carrying` | Conducción | campo | `scripts/player/ball_handler.gd:369`, `scripts/player/ball_handler.gd:1652` |
| `dribbling` | Regate | campo | **sin uso todavía** |
| `short_pass` | Pase corto | campo | `scripts/assistance/pass_assist.gd:100`, `scripts/assistance/pass_assist.gd:228` |
| `long_pass` | Pase largo | campo | `scripts/assistance/cross_assist.gd:93`, `scripts/assistance/cross_assist.gd:103`, `scripts/assistance/pass_assist.gd:100`, `scripts/assistance/pass_assist.gd:228` |
| `pass_accuracy` | Precisión de pase | campo | `scripts/assistance/pass_assist.gd:121`, `scripts/assistance/pass_assist.gd:262`, `scripts/gameplay/set_piece.gd:515` |
| `shot_power` | Potencia de tiro | campo | `scripts/assistance/shot_assist.gd:116` |
| `shot_accuracy` | Precisión de tiro | campo | `scripts/assistance/shot_assist.gd:127`, `scripts/assistance/shot_assist.gd:155`, `scripts/assistance/shot_assist.gd:234` |
| `finishing` | Finalización | campo | `scripts/assistance/shot_assist.gd:128`, `scripts/assistance/shot_assist.gd:155`, `scripts/assistance/shot_assist.gd:234` |
| `weak_foot` | Pierna débil | campo | `scripts/assistance/kick_model.gd:106`, `scripts/assistance/kick_model.gd:109` |
| `reaction` | Reacción | campo | **sin uso todavía** |
| `marking` | Marcaje | campo | `scripts/player/ball_handler.gd:3198` |
| `interception` | Intercepción | campo | **sin uso todavía** |
| `strength` | Fuerza física | campo | `scripts/player/ball_handler.gd:3206`, `scripts/player/player_actions.gd:494`, `scripts/player/player_actions.gd:495` |
| `jumping` | Salto | campo | **sin uso todavía** |
| `heading` | Cabeceo | campo | **sin uso todavía** |
| `composure` | Compostura | campo | `scripts/assistance/pass_assist.gd:131`, `scripts/assistance/pass_assist.gd:270`, `scripts/assistance/shot_assist.gd:139` |
| `decision` | Capacidad de decisión | campo | **sin uso todavía** |
| `reflexes` | Reflejos | arquero | **sin uso todavía** |
| `positioning` | Posicionamiento | arquero | **sin uso todavía** |
| `catching` | Blocaje | arquero | `scripts/goalkeeper/goalkeeper.gd:798` |
| `diving` | Estirada | arquero | `scripts/goalkeeper/goalkeeper.gd:809` |
| `aerial` | Juego aéreo | arquero | **sin uso todavía** |
| `throwing` | Saque con la mano | arquero | **sin uso todavía** |
| `kicking` | Juego con los pies | arquero | **sin uso todavía** |
| `rebound_control` | Reacción a rebotes | arquero | **sin uso todavía** |
<!-- /AUTO -->

Constantes: `MIN_VALUE = 1`, `MAX_VALUE = 100`, `DEFAULT_ROOKIE = 40` (valor inicial de `PlayerAttributes.new()`); en el partido real se usa 55 (`MatchScene._make_footballer`), en las pruebas 50 por defecto (neutro).

### Riesgos al modificar

| Elemento | Efecto real y riesgo |
|---|---|
| `spread` en cada `factor(clave, spread)` | Es el rango de influencia de cada atributo en su sitio de uso (en `Locomotion`, `BallHandler`, `PassAssist`…). Subirlo hace que los atributos dominen la física. |
| `DEFAULT_ROOKIE` / `reset_to(55)` | Cambia el comportamiento base de **todos** los jugadores del partido; varias pruebas fijan atributos explícitos (10, 50, 100) y no se ven afectadas, otras usan 50. |
| Claves de atributos | Se usan como cadenas en el código (`attributes.factor("speed", …)`): renombrar una exige actualizar todos los usos (la tabla anterior los enumera) y `from_dict`. |

## Personalización y logros (2026-11-10)

- `PlayerCustom` (`scripts/progression/player_custom.gd`): paletas de uniforme/piel/pelo (shader del kit), número en la
  espalda (`SpActor.set_back_number`), estilo de golpeo y carrera (pesos sobre `ShotCatalog`, sin tocar la física),
  seguimiento tras el tiro, festejo elegido; cosméticos bloqueados hasta ganarlos. `user://custom.cfg`.
  - Número de la espalda (2026-11-12, «estaba separado de la camiseta»). Con el cuerpo de Tripo va **impreso en la
    tela**:
    - `player_kit.gdshader` proyecta las cifras de `assets/characters/player/number_atlas.png`
      (`tools/ui/make_number_atlas.gd`) sobre la espalda;
    - usa la posición de reposo que `build_tripo_body` guarda en CUSTOM0;
    - contraste automático con la camiseta;
    - se mantiene al cambiar el uniforme.
  - El humanoide, que lo llevaba en un `Label3D`, se eliminó el mismo día: queda un solo cuerpo.
  - Prueba: `test_back_number`; captura: `tools/ui/number_capture.gd`.
- `Achievements` (`scripts/progression/achievements.gd`): logros permanentes + 3 diarios y 2 semanales (rotación por
  fecha, progreso por período, premio único por período, historial). Avisos: autoload `Toasts`. `user://achievements.cfg`.
- Pestaña LOGROS en `ChallengeMenu`; panel «Jugador» en el menú principal.

## Mapa de funciones

<!-- AUTO:funcs:scripts/progression/player_attributes.gd -->
| Función | Línea | Qué hace |
|---|---|---|
| `PlayerAttributes._init()` | 52 |  |
| `PlayerAttributes.reset_to(base: int)` | 55 |  |
| `PlayerAttributes.is_known(key: String)` | 62 |  |
| `PlayerAttributes.display_name(key: String)` | 65 |  |
| `PlayerAttributes.get_value(key: String)` | 72 |  |
| `PlayerAttributes.set_value(key: String, v: int)` | 76 | Asigna un valor respetando el maximo. Devuelve el valor realmente asignado (o -1 si la clave no existe). |
| `PlayerAttributes.factor(key: String, spread: float)` | 83 | Factor multiplicador: 1.0 con valor 50; +-spread en los extremos. |
| `PlayerAttributes.norm(key: String)` | 87 | Valor 0..1 (1 = maximo), util para probabilidades y errores. |
| `PlayerAttributes.total_field()` | 90 |  |
| `PlayerAttributes.overall()` | 96 |  |
| `PlayerAttributes.to_dict()` | 99 |  |
| `PlayerAttributes.from_dict(d: Dictionary)` | 103 | Carga con validacion: ignora claves desconocidas, recorta rangos y rellena las faltantes. |
| `PlayerAttributes.duplicate_attributes()` | 112 |  |
<!-- /AUTO -->

## Pruebas

- **Ejecutar:** no hay un archivo de pruebas de `PlayerAttributes`; se ejercita indirectamente: `tools/run_tests.sh passing` (precisión de pase con atributos 10 vs 100), `locomotion` y `dribbling`.
- **Última ejecución (2026-10-26):** suite completa 57 pruebas / 212 comprobaciones sin fallos.
- **Alcance real:** **`PlayerAttributes.from_dict`/`to_dict`/`overall`/`set_value` no tienen prueba directa.**

## Limitaciones conocidas (pendientes)

- Atributos sin uso en el código (aparecen con «sin uso» en la tabla de arriba), entre ellos `dribbling`, y todos los de arquero.
- No hay mapeo de atributos → apariencia/ficha, ni persistencia de jugadores (`user://` solo guarda asistencias, diagnóstico y gráficos).
- Sin sistema de progresión ni estadísticas: los `GameEvent` se emiten pero nadie los acumula.

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Control asistido» (los atributos escalan locomoción, conducción y asistencias).
