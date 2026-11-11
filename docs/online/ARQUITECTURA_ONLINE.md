# Ecosistema online — auditoría y arquitectura (etapa 1)

Pedido: «CREACIÓN DEL ECOSISTEMA ONLINE, CUENTAS, PERSONALIZACIÓN, IA, PROGRESIÓN, ECONOMÍA Y PREPARACIÓN WEB»
(2026-11-11). Este documento es el punto de partida y se actualiza con cada entrega. Estado real por etapa al final.

## 1. Inventario de lo que ya existe (verificado en el código)

| Sistema | Dónde | Qué se reutiliza |
|---|---|---|
| Penales y tiros libres | `scripts/setpiece/setpiece_game.gd` (`SetPieceGame`), `sp_keeper.gd`, `sp_shooter.gd`, `penalty_shootout.gd` | Partida completa contra la IA, gesto táctil (`ShotGesture` → `GestureShotModel` → `ShotParams`), tiro de la IA con el mismo modelo (`_cpu_penalty`), arquero con zonas seguras (`KeeperZones`), tanda con muerte súbita. |
| Gesto táctil y ratón | `shot_gesture.gd`, `gesture_shot_model.gd`, `gesture_tuning.gd` | Sin cambios: el online usa el mismo trazo. |
| Pelota y física | `scripts/ball/*`, `ShotSolver`, `BallPredictor` | Sin cambios. |
| Minijuegos | `scripts/minigames/*` (`Minigame` base, turnos, IA con la misma física) | Botón de caída («A la vista»), Duelo del guante, Dardos, Básquet (Enceste), Dianas (incluye «Diana en el suelo»). |
| Progreso local | `scripts/challenges/player_progress.gd` (XP, nivel, récords, cosméticos; `user://progress.cfg`) | Se convierte en caché local del perfil del servidor. |
| Personalización | `scripts/progression/player_custom.gd` (camiseta, short, medias, botines, piel, pelo, número, estilos, festejo; shader del kit) | Base de la personalización; los ítems del catálogo se mapean a estos parámetros. |
| Logros y diarios | `scripts/progression/achievements.gd` | Siguen locales; sus premios pasan por la cola de sincronización. |
| Atributos | `scripts/progression/player_attributes.gd` (`factor/norm` escalan parámetros con límites) | Base de los 6 atributos de disparo pedidos. |
| Repeticiones | `scripts/replay/play_recording.gd` (por estados, interpola entre pasos) | Se revisa en la etapa 9. |
| Diagnóstico | botón «Diag.», `GestureDiagnostics`, línea de destino (`TrajectoryPreview`, `GraphicsSettings.show_aim_line`) | Se ocultan en las builds públicas (bandera de compilación). |
| Red | `scripts/network/*` (`InputFrame`, `BallState`, `GameEvent`: estructuras serializables del modo partido) | Referencia de formato; el online de turnos usa su propio protocolo. |
| Modelo 3D | `assets/characters/player/player_base.glb` + `player_albedo.jpg` → `assets/characters/json/json_human.scn` | El GLB enviado (`jugador_futbol5_tripo_con_huesos.glb`) es **idéntico byte a byte** al modelo ya integrado: misma malla (7640 triángulos), mismo esqueleto (23 huesos `mixamorig`), mismos pesos y misma textura 1024². No hay nada nuevo que importar. |

No existía: cuentas, backend, monedas, inventario, tienda, temporadas, eventos, rankings, matchmaking, chat.

## 2. Backend: decisión y bloqueo

- La cuenta de Supabase conectada a esta sesión tiene **un solo proyecto, «El Maletin App», pausado (INACTIVE)**, que
  es de otra aplicación. No se crearon tablas ahí (mezclaría datos de otro producto) ni se creó un proyecto nuevo
  (puede tener costo): **hace falta que el usuario cree o indique el proyecto de Free-Kick-Swipe.**
- Todo el servidor está escrito como migraciones SQL en `supabase/migrations/` y se **probó de verdad** contra un
  PostgreSQL 16 local con una simulación mínima del esquema `auth` de Supabase (`supabase/tests/`).
- El cliente lee la URL y la clave pública (anon/publishable) de `res://config/backend.json`, que CI genera desde los
  GitHub Secrets `SUPABASE_URL` y `SUPABASE_ANON_KEY`. **Nunca** se usa la service key en el cliente: solo la usan las
  funciones del servidor (webhooks de pago, cuando existan).
- Sin configuración (pruebas, PC de desarrollo o una APK sin esos secretos) el cliente usa `LocalBackend`, que imita
  la misma API en el dispositivo y se identifica como «servidor no configurado». No es el online real.

## 3. Arquitectura

```
Godot (cliente: presentación, controles, simulación visual)
  Backend (interfaz)  ── SupabaseBackend (HTTP: GoTrue /auth/v1, PostgREST /rest/v1, RPC)
                      └─ LocalBackend (sin servidor: misma API, datos en user://)
  AuthManager         sesión, registro, inicio, recuperación, cierre, recordar sesión, renovación del token
  CloudSync           caché local del perfil + cola de operaciones con clave de idempotencia
  Profile/Inventory/Economy/Season/Event/Leaderboard: lecturas del servidor; toda escritura de valor por RPC
  Matchmaking + OnlineMatch: cola → humano o bot; turnos con reloj de 20 s; chat y reacciones
  BotFactory/BotPersonality/AdaptiveDifficulty/BehaviorMirror: rivales IA bajo demanda (solo decisiones, misma física)

Supabase (autoridad)
  Auth (correo + contraseña, verificación de correo, recuperación)
  PostgreSQL con RLS en todas las tablas; el cliente solo LEE lo suyo
  Funciones SECURITY DEFINER = única forma de cambiar monedas, XP, inventario, partidas, rankings
  Webhooks de pago (Edge Function con service key) → grant_purchase (solo service_role)
```

Reglas de autoridad (todas implementadas en SQL):

- Monedas, XP, inventario, compras con monedas, consumibles, temporadas: solo por funciones del servidor, con libro
  mayor (`reward_ledger`) y clave de idempotencia única por usuario (una misma recompensa nunca se cobra dos veces).
- Recompensas offline: el servidor las recalcula con su propia tabla (no acepta montos del cliente), con topes diarios.
- Partidas: el servidor crea la partida, guarda el orden de turnos y el plazo de cada uno, oculta la zona del arquero
  hasta que llega el tiro, rechaza resultados incoherentes con la regla de zonas y liquida premios y ranking una sola vez.
- Bots: los genera el servidor (nombre, personalidad, habilidad, semilla) dentro de la partida; no tienen fila de
  usuario, no entran en `player_stats` ni en rankings, y una partida contra bot no da puntos de ranking.

## 4. Riesgos

- **Sin proyecto Supabase no hay online real**: el código y el SQL están probados localmente, pero falta la conexión.
- Física no determinista entre dispositivos (Jolt): en una partida humana el resultado de cada tiro lo simula el
  cliente del que patea y el servidor lo valida por coherencia (zona del arquero, rangos), no re-simulando.
- Google Play exige su facturación para bienes digitales en apps distribuidas por Play Store (ver `PAGOS.md`).
- El rendimiento de lo nuevo en el teléfono de referencia (ZTE V60 / Mali-G57) no se midió.

## 5. Estado por etapa

| Etapa | Estado | Qué hay | Qué falta |
|---|---|---|---|
| 1. Auditoría | **Hecha** | Este documento. El GLB enviado es el modelo ya integrado. | — |
| 2. Supabase y cuentas | **Hecha (sin proyecto conectado)** | Esquema con RLS y funciones del servidor; 66 pruebas SQL OK. Cliente: registro, inicio de sesión, recuperación, cierre, recordar sesión (cifrada), modo offline con la sesión guardada, cola de sincronización idempotente; bienvenida obligatoria. | Proyecto de Supabase y GitHub Secrets; verificación de correo y SMTP en Supabase. |
| 3. Perfil y personalización | **Parcial** | Identidad (nombre, apodo, número, país), cambio de nombre con límite. Camisetas con diseños reales en el juego (rayas, banda, aros, mitad, degradé, rayas finas) y dos colores; short (franja, ribete); medias (rayas, ribete, altura); botines, piel, pelo; vista 3D que se gira; desbloqueos gratis / nivel / temporada / evento / tienda validados por el servidor. | Modelos 3D distintos de botines (hoy cambia el color), diseños visuales de balón y números míticos en el juego (se guardan, no se ven todavía), peinados y bandera. |
| 4. Online y matchmaking | **Hecha (penales)** | Humanos primero y bot después de 8 s; bots con nombre, avatar, personalidad, habilidad adaptativa e historial; turnos de 20 s; abandono; chat con frases, emojis y moderación; reacciones del bot; lobby con humanos reales y «actividad del mundo» separada. | Probar humano contra humano entre dos dispositivos (el protocolo está probado en SQL). |
| 5. Penales y tiros libres online | **Penales: hecho. Tiros libres: falta** | Penales online contra bot con el juego real, regla de zonas validada en el servidor y marcador igual al del servidor. | Tiros libres online: elección de distancia y arquero del usuario en el tiro libre. |
| 6. Minijuegos online | **Falta** | Se muestran «en preparación» (A la vista, Guante, Dardos, Basket, Diana). El servidor ya admite partidas por puntos con tope por turno. | Partida online de cada minijuego. |
| 7. Progresión y economía | **Parcial** | XP, nivel, monedas, consumibles (sin acumulación), puntos de atributo (2 por nivel), rankings sin bots, topes antiabuso: todo en el servidor. | Efecto de los 6 atributos en la física (hoy se guardan y se gastan, no cambian el tiro). |
| 8. Tienda y temporada | **Hecha (monedas virtuales)** | Tienda con rarezas y desbloqueos; pase de temporada con 30 niveles (gratis y premium); compras reales preparadas e INACTIVAS; comparación de proveedores (`PAGOS.md`). | Elegir proveedor; webhook; activar pagos (con tu aprobación). |
| 9. Eventos y presentación | **Parcial** | Eventos configurables desde datos del backend (tarjetas grandes, progreso, recompensas); menú con 10 entradas, íconos propios y fondo de tiro libre en cámara lenta con partículas; público que festeja. | Repeticiones (no se tocaron en esta entrega), más efectos y sonidos de interfaz. |
| 10. Validación y Web | **Parcial** | Suite completa, CI con job de servidor, APK con permiso INTERNET, build pública sin herramientas de desarrollo, auditoría Web (`WEB.md`). | Exportación Web real y pruebas en el teléfono. |
