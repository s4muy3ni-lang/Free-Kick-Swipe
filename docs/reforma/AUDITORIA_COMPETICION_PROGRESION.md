# Auditoría y plan — Competición, atajadas, duelo local, tienda, personalización, minijuegos online, Rescate y progresión

Fecha: 2026-11-13. Pedidos del usuario: «ACTUALIZACIÓN INTEGRAL DE COMPETICIÓN, ATAJADAS, DUELO LOCAL, TIENDA,
PERSONALIZACIÓN Y MINIJUEGOS ONLINE» y «EXPANSIÓN DEL SISTEMA DE PROGRESIÓN, MEJORAS DE ATRIBUTOS Y PERSONALIZACIÓN
AVANZADA». Este documento es la auditoría inicial que piden los dos pedidos. El estado real de cada etapa está en
`docs/technical-index/CHANGELOG.md`.

## 1. Lo que ya existe (auditado en el código)

| Área | Sistema actual | Archivos | Qué se reutiliza |
|---|---|---|---|
| Penales | Tanda contra la CPU que **ya alterna** tirador y arquero. El usuario ataja tocando el arco (`_pick_zone`). Hay 6 zonas (3 columnas × 2 alturas), con atajada **garantizada** si el tiro entra en la zona elegida (`SpKeeper.sure_save_check`, con la estirada guiada hacia la pelota). | `setpiece_game.gd`, `keeper_zones.gd`, `sp_keeper.gd`, `penalty_shootout.gd` | Turnos, tanda, cámaras, estirada guiada, planificador de estiradas (`KeeperPlanner`) |
| Tiros libres | Solo patea el usuario («Goles X / Y»). La CPU ataja leyendo la pelota real con reacción y error; hay barrera y sueltos. | `setpiece_game.gd`, `sp_keeper.gd` (`read_shot`, `wall_blocks`), `sp_wall.gd` | Barrera, cámara, gesto, física, IA del arquero |
| Tiro del usuario | Gesto → `GestureShotModel` → `ShotParams` (`error_deg`, potencia, efecto) → `_take_shot` (`ShotSolver.perturb`) | `gesture_shot_model.gd`, `gesture_tuning.gd`, `shot_solver.gd` | Los atributos escalan estos parámetros (precisión → `error_deg`, potencia → velocidad, efecto → `spin_max`) |
| Online penales | Protocolo de turnos con autoridad del servidor: el arquero elige una zona oculta (`keeper_pick`, que se revela con el tiro) y el servidor aplica la regla de zonas y liquida. Bot si no hay humano. | `online_match.gd`, `local_backend.gd`, `supabase/migrations/*_match_functions.sql` | El mismo protocolo sirve para los tiros libres |
| Online minijuegos y tiros libres | `OnlineDuel`: contra un bot. Los tiros libres se juegan por puntaje (5 tiros) y los minijuegos en el **nivel 1**. Al terminar, «Siguiente nivel» abre el nivel 2 **fuera del online**: parece otro juego (el error que vio el usuario). | `online_duel.gd`, `minigame.gd` (`_on_action &"next"`) | Selector de nivel con el catálogo real (`MinigameCatalog.levels`) |
| Tienda | Tarjetas solo de texto (`_item_card`) desde `catalog_items` (45 objetos: 10 camisetas, 7 balones, 6 botines, 3 shorts, 3 medias…). La compra la valida el servidor (`buy_item`). | `menu_screens.gd`, `seed.json`, `local_backend.gd` | Catálogo, inventario y compra del servidor |
| Personalización | Pestañas, muestras de color y diseños aplicados al shader del uniforme (`player_kit.gdshader`). Hay un jugador en el menú, **quieto**. | `menu_screens.gd`, `player_custom.gd`, `main_menu.gd`, `player_kit.gdshader` | Shader del uniforme (diseños en posición de reposo), número impreso |
| Dominadas | `JuggleController` (modo práctica) usa clips de malabares del pack de Mixamo **borrado**. El banco JSON **no tiene clips de dominadas**. | `juggle_controller.gd` | Se hacen con IK de dos huesos (`TouchFootIK.ik_toe`) y una pelota física pateada con impulsos |
| Atributos | **Existen en el servidor** (potencia, precisión, efecto, altura, técnica, control; de 1 a 10; 2 puntos por nivel; `spend_attribute_point`), pero **no tienen ningún efecto en el juego**. `PlayerAttributes` (1-100) es del modo partido. | `local_backend.gd`, SQL, `menu_screens.gd` (Perfil) | La validación del servidor; falta conectarlos a la física y al tiro |
| XP y topes | XP por fuente con topes diarios del servidor (`offline_xp` 1500, `offline_coins` 800…) e idempotencia. | `local_backend.gd` (`_claim_reward`), SQL | Las fuentes nuevas pasan por la misma cola con tope |
| Rescate | 4 niveles: se patea una pelota contra botones, una traba o fichas de dominó. **Sin mecanismos táctiles** ni acertijos. | `rescate.gd`, `minigames.json` | `Minigame` (estados, puntaje, cámara, online por puntaje) |

## 2. Arquitectura de los cambios

- **Atajadas (todos los modos):**
  - `KeeperZones` pasa a 9 sectores (3 × 3).
  - `KeeperReach` (nuevo, compartido) decide si un punto del arco está al alcance físico de la estirada. Mira el
    sector elegido, la altura, la distancia lateral desde el arquero y el tiempo disponible (velocidad del tiro).
  - La estirada guiada solo se activa si el tiro va al sector elegido **y** está al alcance. Si no, el arquero se
    tira igual al sector y decide la física (contacto real con las esferas de los huesos).
  - La misma regla usan el usuario, la IA, el duelo local y el servidor.
- **Turnos:** `SetPieceGame` ya alterna en penales; los tiros libres usan el mismo patrón (patea el usuario, patea la
  CPU con barrera propia, el usuario elige sector).
  - El duelo local reemplaza «CPU» por «Jugador 2», con pantallas de cambio de turno que ocultan el sector.
  - El online usa el protocolo de turnos de los penales con la regla nueva en el servidor.
- **Minijuegos online:** el nivel se elige en el lobby (o se sortea). Se guarda en la partida del servidor y
  `OnlineDuel` arranca ese nivel. Al terminar se ofrece repetir, siguiente nivel del mismo minijuego (sigue online),
  elegir otro o salir; nunca un salto a otro minijuego.
- **Atributos:** `ShotAttributes` (nuevo) traduce los atributos del perfil a parámetros con límites: precisión →
  `error_deg`, potencia → rango de velocidad, efecto → `spin_max`, altura → error vertical, técnica → golpe defectuoso,
  control → error por trazo irregular; reflejos, alcance y blocaje del arquero → `KeeperReach`. Un atributo alto
  **nunca** asegura el gol: el gesto sigue mandando.
- **Datos y servidor:** la economía, las compras y los atributos siguen validados por el servidor (`LocalBackend` en
  pruebas, Supabase en producción, migraciones nuevas). El cliente nunca guarda claves privadas.

## 3. Etapas (orden de implementación)

1. Atajadas por 9 sectores con alcance físico, grilla táctil y regla del servidor.
2. Tiros libres alternados contra la IA.
3. Duelo local de dos jugadores.
4. Tiros libres online con roles alternados.
5. Minijuegos online: elegir nivel o aleatorio.
6. Rescate rediseñado.
7. Tienda visual.
8. Personalización con dominadas, cámara girable y botines visibles.
9. Progresión: atributos con efecto real, XP y pantalla MI JUGADOR.
10. Personalización avanzada.
11. Documentación, CI y APK.

## 4. Límites conocidos desde el inicio

- **Modelos 3D nuevos:** generar botines, peinados o accesorios como modelos nuevos con Tripo3D cuesta créditos. Las
  reglas del proyecto piden comprobar el costo, respetar el presupuesto y anotar cada gasto, y estos pedidos no
  autorizan ese gasto. Por eso:
  - los botines, la indumentaria y los balones cambian con diseños del shader **sobre las mallas reales**, que se ven
    en el pie, en el cuerpo y en la pelota;
  - los accesorios son mallas simples pegadas a los huesos.
- **Online entre dos teléfonos:** no se puede probar desde aquí. Las pruebas usan el servidor local con las mismas
  reglas que el SQL, y bots como rivales.
- **Android físico:** no se puede probar desde aquí. Se compila el APK en CI y se mide en PC.
