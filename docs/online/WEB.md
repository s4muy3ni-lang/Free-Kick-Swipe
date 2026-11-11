# Preparación Web (Bolt.new) — auditoría de compatibilidad

Estado: **auditoría en papel. No se exportó a Web ni se probó en un navegador.** El pedido era no convertir nada
automáticamente sin comprobar compatibilidad: esto es la lista de lo que hay que comprobar y de lo que ya se dejó
preparado.

## Qué ya favorece la Web

| Tema | Estado en el proyecto |
|---|---|
| Renderizado | GL Compatibility (WebGL 2): es el renderer que Godot usa en la Web. |
| Peso | Público en 2D (una MultiMesh), tribunas y decoración en pocas mallas, sin texturas grandes nuevas. |
| Backend | Supabase por HTTP (`SupabaseApi` con `HTTPRequest`, que en la Web usa `fetch`). Supabase admite CORS: la misma cuenta, el mismo perfil, el mismo inventario y los mismos rankings sirven para Android, PC y Web. |
| Sin plugins nativos | No hay plugins de Android ni APIs nativas: solo el permiso INTERNET. |
| Entrada | El gesto usa `InputEventScreenTouch/Drag` y el ratón: los dos existen en la Web. |
| Herramientas de desarrollo | `DevFlags`: con la característica `public`, la build oculta «Diag.», la línea de destino y el banco de animaciones. El preset Web también debe llevarla. |

## Riesgos a comprobar antes de publicar

1. **Física Jolt en la Web:** verificar que el módulo Jolt de Godot 4.7 esté en la plantilla Web. Si no, la física
   cambia de motor y hay que repetir las pruebas de pelota y arquero.
2. **Hilos:** exportar en modo de un solo hilo, para no exigir los encabezados COOP/COEP (SharedArrayBuffer) en el
   hosting. Medir el rendimiento así.
3. **Almacenamiento:** `user://` va a IndexedDB. `OS.get_unique_id()` vale vacío en la Web, así que la sesión
   recordada queda cifrada con una clave derivada más débil. En la Web conviene no «recordar sesión», o guardar solo
   el refresh token.
4. **Audio:** el navegador exige un toque antes de reproducir sonido. El público y los efectos arrancan después del
   primer toque (ya pasa en la bienvenida).
5. **Tamaño de descarga:** el banco de animaciones JSON y los clips pesan. Medir el `.pck` y usar compresión
   (Brotli/gzip en el hosting).
6. **Móvil en el navegador:** WebGL 2 en Mali-G57 con Chrome. Medir los FPS reales.

## Arquitectura propuesta con Bolt.new

- **Bolt.new arma la parte web «de aplicación»:**
  - portada, inicio de sesión con supabase-js, perfil, tienda, temporada y rankings en React;
  - todo contra el MISMO proyecto de Supabase y las MISMAS funciones del servidor.
- **El juego (la exportación Web de Godot) se integra como página o `iframe`:**
  - recibe la sesión de Supabase por `postMessage`, o la vuelve a pedir;
  - se juega igual que en Android.
- **Datos compartidos sin duplicar lógica:**
  - toda regla de valor ya está en SQL (`supabase/migrations`), así que la web de Bolt no reimplementa premios ni
    compras: llama a las mismas RPC;
  - los pagos web van por el webhook previsto en `PAGOS.md`.

## Próximos pasos

1. Agregar un preset Web en `export_presets.cfg` (de un solo hilo, característica `public`).
2. Hacer un job de CI que exporte la Web y publique el artefacto (aparte del de la APK).
3. Probar en Chrome de escritorio y en Chrome de Android: gesto, física, audio y login.
