# ANDROID — Exportación de la APK de prueba (liviana) y CI

## Identificación

- **Responsabilidad:** generar una APK instalable de Fútbol 5 para probar en un teléfono, de forma reproducible en GitHub Actions, sin secretos en el repositorio.
- **Estado real:** la exportación y la firma están verificadas en Linux (ver «Qué se verificó»); el workflow ya se ejecutó en un runner (pruebas, exportación y firma pasan; la subida del artefacto falló por la cuota de almacenamiento de la cuenta, no por el código). **Nada se probó en un teléfono ni en un emulador.**
- **Última verificación:** <!-- AUTO:verified -->
2026-11-10
<!-- /AUTO -->

## Cliente liviano: qué lo hace liviano

| Medida | Dónde | Efecto medido |
|---|---|---|
| Solo `arm64-v8a` (sin armeabi-v7a/x86) | `export_presets.cfg` `architectures/*` | un solo `libgodot_android.so` (24 MB comprimido) |
| Sin Gradle | `gradle_build/use_gradle_build=false` | exporta en ~15 s; sin Kotlin/AndroidX extra más allá de la plantilla |
| Sin permisos | `export_presets.cfg` (ninguno marcado) | `aapt2 dump badging`: ningún `uses-permission` |
| Filtro de exportación | `exclude_filter`: `tests/*`, `tools/*`, `docs/*`, `pack/*`, `assets/animations/source/*`, `*v1_*.glb`, `*.md` | el APK lleva `pack_clips.res` (6.5 MB) y `pack_keeper.res` (2.3 MB) pero ningún FBX |
| Release, no debug | `--export-release` | scripts `.gdc` compilados, no depurable |
| **Total** | | **APK de 34.0 MB** (medido localmente con las 133 animaciones) |

## Cómo se obtiene la APK

1. Subir el proyecto a un repositorio de GitHub y abrir *Actions → Android APK → Run workflow* (también corre en cada `push` a `main`, `master` o la rama de trabajo).
2. El workflow instala Godot 4.7.2, el SDK de Android y el JDK, importa el proyecto, ejecuta las pruebas headless, exporta y **firma con un keystore de depuración estándar de Android creado en cada ejecución** (alias `androiddebugkey`, contraseña `android`): no hay secretos ni clave permanente. Consecuencia: cada APK tiene una firma distinta, así que hay que **desinstalar la anterior** antes de instalar la nueva.
3. Verifica la firma (v2), el paquete `com.webmaletin.futbol5`, `arm64-v8a`, la ausencia de permisos y que las dos librerías de animaciones dentro de la APK son idénticas a las del repositorio.
4. Publica el APK como **artefacto** `futbol5-apk` (14 días; necesita iniciar sesión en GitHub para descargarlo y consume la cuota de almacenamiento de artefactos de la cuenta).
5. **Para que otras personas prueben el juego sin cuenta de GitHub:** lanzar el workflow a mano con `publish_release` activado. Además de la ejecución normal crea una **pre-release de prueba** (`apk-prueba-<n>`) con el APK adjunto y una URL pública de descarga; las releases no gastan la cuota de artefactos, y si la subida del artefacto falla la ejecución no se marca como fallida. En el teléfono hay que permitir «instalar apps desconocidas» para el navegador la primera vez.
6. `versionCode` = número de ejecución (siempre creciente); `versionName` = `0.1.<n>`.

## Animaciones en la APK

assets/animations/pack_clips.res (borrado: Mixamo/Mocap) y `pack_keeper.res` (las 133 animaciones ya convertidas al formato del juego) van dentro de la APK; los FBX originales **no** (`pack/` está en `.gitignore` y fuera del filtro de exportación: solo hacen falta para regenerar las librerías, ver [ANIMATION_PACK](ANIMATION_PACK.md)). El workflow se detiene si falta alguna de las dos librerías (salvo ejecución manual con `allow_without_pack`, que cae a los clips de Tripo).

## Lo que existe (verificado)

| Elemento | Dónde | Valor / estado |
|---|---|---|
| Renderer | `project.godot` `[rendering]` | `renderer/rendering_method="gl_compatibility"` y `renderer/rendering_method.mobile="gl_compatibility"` |
| Orientación | `project.godot` `[display]` | `window/handheld/orientation=0` (horizontal), ventana base 1280×720, `stretch/mode="canvas_items"`, `aspect="expand"` |
| Texturas móviles | `project.godot` `[rendering]` | `textures/vram_compression/import_etc2_astc=true` |
| Entrada táctil | [INPUTS](INPUTS.md) | joystick flotante y botones; `pointing/emulate_touch_from_mouse=true` |
| Perfil gráfico inicial en Android | [PERFORMANCE](PERFORMANCE.md) | por número de núcleos (`GraphicsSettings.detect_default_profile`) |
| Plantillas de exportación | máquina de la sesión: `~/.local/share/godot/export_templates/4.7.2.stable/` (incluye `android_debug.apk`, `android_release.apk`, `android_source.zip`) | **entorno local, no versionado** |
| `.gitignore` | raíz | ya excluye `*.apk`, `*.aab`, `*.keystore`, `*.jks`, `/android/build/`, `/build/`, `.env`, `.tripo/` (los secretos no se versionan) |
| Icono | `icon.svg` | icono genérico del proyecto |

## Lo que NO existe todavía

1. Prueba real en un dispositivo: rendimiento, multitoque, pausa/segundo plano, persistencia de `user://`, tiempo de carga, consumo y temperatura.
2. Icono adaptativo propio (usa el icono genérico `icon.svg`; la plantilla avisa de `themed_icon` sin ruta, sin efecto en la instalación), política de privacidad y metadatos de tienda. No hay monetización ni anuncios; no es una compilación para Google Play (AAB, API objetivo, firma de Play).
3. Plantilla de motor reducida (módulos desactivados) para bajar de ~25 MB.
4. Prueba en un teléfono físico (rendimiento, multitoque, pausa/segundo plano).

## Mapa de parámetros

No hay parámetros propios; ver `project.godot` (`[display]`, `[rendering]`, `[input_devices]`).

## Qué se verificó (2026-10-26, Godot 4.7.2 en Linux; nada en Android)

- Exportación local con Android SDK (`platform-tools`, `build-tools;35.0.1`, `platforms;android-35`) y JDK 21: `godot --headless --path . --export-release Android build/futbol5.apk` → **28.3 MB**, ~15 s, también con **solo** `android_release.apk` como plantilla y el fichero de ajustes generado como lo hace el workflow.
- `apksigner verify`: verificada con esquema **v2 y v3**, un firmante; `aapt2 dump badging`: `com.webmaletin.futbol5`, `native-code: arm64-v8a`, sin permisos. Dos exportaciones con el mismo keystore dieron **la misma huella SHA-256** del certificado.
- `tools/android/make_keystore.sh`: probado con un keystore temporal (ida y vuelta de base64; se niega a sobrescribir).
- Workflow en runner (`ubuntu-24.04`): el run nº 1 (versión anterior del flujo, sin secretos) completó Godot, SDK, importación, pruebas headless, exportación y verificación de firma, y se detuvo en el paso de secretos. Resultado de las ejecuciones siguientes: ver el CHANGELOG.
- Exportación local con las 133 animaciones (2026-10-26, mismo flujo que el workflow, keystore de depuración temporal): **34.0 MB**, `apksigner verify` correcto, `com.webmaletin.futbol5`, `arm64-v8a`, sin permisos; `pack_clips.res` (6.5 MB) y `pack_keeper.res` (2.3 MB) dentro de la APK y **idénticas** (`cmp`) a las del repositorio; ningún FBX dentro.
- **No se verificó:** instalar la APK en un teléfono, actualizar encima de otra versión (se deduce de la firma y del `versionCode`, no se probó), ni el juego corriendo en Android.

## Qué podría romperse en Android (sin verificar)

Rutas `res://` de recursos importados, compresión de texturas (ETC2/ASTC) del GLB, rendimiento del shader del kit, memoria, `OS.add_logger` del diagnóstico, escritura en `user://`, controles táctiles reales (hasta ahora solo emulados por ratón/`ScriptedInput`).

## Historial

Ver [CHANGELOG.md](../CHANGELOG.md): «Base del juego» (ajustes de proyecto).

## Integración 2026-11-07

El workflow conserva Godot 4.7.2 y sus plantillas Android oficiales. Antes de exportar ejecuta
`tools/integration/audit_bank.tscn`; sube JSON y log como `animation-audit`, incluso si falla la auditoría.
Las pruebas con render son bloqueantes y usan X11 explícito con Xvfb. El APK sigue siendo artefacto de prueba;
`publish_release` permanece desactivado por defecto. En esta sesión el dispatch fue rechazado por GitHub con HTTP 403
(`Resource not accessible by integration`); no hay ejecución ni APK nuevos. Detalle en `docs/integration/INFORME.md`.


## Continuación de integración (2026-11-07)

Workflow Android activado por push en integracion-openai; publicación exclusivamente como artefacto, sin pasos de Release y con contents:read. Despacho externo aún devuelve 403; un push sí inició una ejecución real. [Seguimiento](../../integration/continuacion/README.md).
