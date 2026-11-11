# Esquema de Supabase, seguridad y puesta en marcha

## Puesta en marcha (lo que falta hacer, con acceso al proyecto)

1. Crear (o indicar) el proyecto de Supabase de Free-Kick-Swipe. El único proyecto visible en esta sesión era
   «El Maletin App», que está pausado y es de otra aplicación, así que no se tocó.
2. Aplicar las migraciones en orden:
   - Supabase CLI: `supabase db push`;
   - o desde el SQL editor: `supabase/migrations/20261111000001_core.sql` … `..._000005_grants_and_seed.sql`.
   - `supabase/tests/00_supabase_stub.sql` **no** se aplica: solo imita a Supabase en local.
3. En Auth, activar «Confirm email» (verificación de correo) y configurar el SMTP propio: el de Supabase tiene un
   límite bajo de correos.
4. En GitHub (Settings → Secrets and variables → Actions):
   - `SUPABASE_URL` = `https://<ref>.supabase.co`;
   - `SUPABASE_ANON_KEY` = clave **pública** (anon o `sb_publishable_…`).
   - CI genera `config/backend.json`. **Nunca** cargar ahí la service key; CI y el cliente la rechazan.
5. Correr los Security Advisors de Supabase después de aplicar.

## Tablas

| Tabla | Para qué | El cliente puede |
|---|---|---|
| `profiles` | Perfil: nombre de usuario único, nombre visible, número, XP, monedas, puntos de temporada, apariencia, atributos | Leer la suya |
| `catalog_items` | Cosméticos y consumibles, con su forma de desbloqueo (free / progression / season / event / shop) | Leer (los activos) |
| `store_products`, `purchases` | Productos con dinero real (inactivos) y registro de compras | Leer las suyas |
| `inventory` | Objetos de cada jugador | Leer el suyo |
| `reward_ledger` | Libro de cada cobro o pago, con clave de idempotencia única por usuario | Leer el suyo |
| `boosts` | Consumibles activos (monedas ×2 por partidas, XP ×2 por minutos, escudo de racha) | Leer los suyos |
| `game_modes` | Modalidades online: reglas, entradas, rondas, plazo, arte | Leer |
| `seasons`, `season_tiers`, `season_progress` | Temporada, niveles con premio gratis y premium, progreso | Leer (el progreso, el suyo) |
| `events`, `event_progress` | Eventos configurables por datos, progreso | Leer (el progreso, el suyo) |
| `player_stats` | Estadísticas por temporada y modo; `vs_bots` separa lo jugado contra la IA | Leer las suyas |
| `presence` | Latido (humanos conectados de verdad) | — |
| `matchmaking_queue`, `matches`, `match_turns`, `chat_messages` | Búsqueda, partidas, turnos (la zona del arquero queda oculta hasta el tiro), chat | Leer las de sus partidas |
| `bot_skill` | Habilidad adaptativa del bot por jugador y modo | — |

Todas tienen **RLS activado**. No hay ninguna política de escritura para el cliente: toda escritura pasa por funciones.

## Funciones del servidor (las únicas que cambian algo)

| Función | Validación |
|---|---|
| `create_profile`, `change_username`, `update_identity` | Formato del nombre, único sin importar mayúsculas, cambio de nombre: el primero gratis y después cada 30 días |
| `update_appearance` | Cada objeto equipado tiene que ser gratuito o estar en el inventario; colores y estilos básicos libres; claves desconocidas rechazadas |
| `spend_attribute_point` | 2 puntos por nivel, máximo 10 por atributo |
| `claim_reward` | El servidor calcula el monto (del cliente solo toma medalla o victoria); idempotente; topes diarios de XP, monedas y puntos de temporada |
| `buy_item` | Precio, nivel mínimo, saldo; no compra dos veces lo mismo; idempotente |
| `use_consumable` | No se acumula con otro igual activo |
| `claim_season_tier` | Puntos alcanzados, pase premium para la pista premium, una sola vez |
| `find_match`, `start_bot_match`, `cancel_search` | Humanos primero (nivel parecido o 20 s de espera, conectados hace menos de 30 s, con saldo para la entrada); el bot solo después de 8 s en la cola |
| `submit_turn`, `claim_timeout`, `leave_match` | Turno y lado correctos, plazo, zona oculta, regla de zonas, tope de puntos por turno, abandono por tiempos vencidos |
| `_settle` (interna) | Premios una sola vez por partida, estadísticas, Elo solo entre humanos, eventos |
| `send_chat` | Frecuencia (2 s), cantidad (30 por partida), frases y emojis de una lista, filtro de palabras |
| `get_lobby`, `get_leaderboard`, `get_events`, `get_match`, `get_my_state`, `heartbeat` | Lectura con las reglas de visibilidad |
| `grant_purchase` | Solo `service_role` (webhook); entrega una sola vez |

## Amenazas consideradas

| Amenaza | Defensa |
|---|---|
| Cliente modificado que se suma monedas o XP | No hay permiso de escritura en tablas; montos calculados en el servidor. |
| Reenviar la misma recompensa | Clave de idempotencia única por usuario. |
| Granjear premios offline | Topes diarios de XP, monedas y puntos de temporada. |
| Informar «gol» cuando el arquero eligió esa zona | El servidor tiene la zona oculta y lo cuenta atajada. |
| Ver la zona del arquero antes de patear | RLS en `match_turns` y payload vacío en `get_match` hasta el tiro. |
| Manipular las partidas contra bots | Premios reducidos con tope diario, sin ranking. |
| Bots en los rankings | Sin fila de usuario; las estadísticas van en `vs_bots`. |
| Robo de la sesión del teléfono | Sesión guardada cifrada (clave derivada del dispositivo); «recordar sesión» opcional. |
| Contraseñas | Las maneja Supabase Auth (bcrypt). En `LocalBackend`, sal y hash SHA-256 iterado (solo para pruebas sin servidor). |
| Service key filtrada en la app | El cliente y CI rechazan claves `sb_secret_…` o `service_role`. |

## Pruebas

`supabase/tests/run_local.sh` corre en CI (job «servidor») sobre PostgreSQL. En esta sesión: **66 comprobaciones,
todas OK**.
