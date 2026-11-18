# Crash de LAS Recomp en Mali-G57 MP4 (Unisoc T820)

Fecha: 2026-11-17/18. Dispositivo de prueba: nubia Neo 2 5G (Z2352N), Unisoc T820, Mali-G57 MP4,
Android 13 (SDK 33), 7.3 GB RAM, 2400x1080. Driver Mali:
`v1.r40p0-01eac0.b0251c048237dcd59e6be15fba11a31a`, Vulkan 1.3.225.

Apps probadas:

- **beta_6 oficial v0.6.0** (`com.lasrecomp.android`)
- **nightly `c2e7e27` 2026-11-17** (`com.lasrecomp.android.nightly`)
- **fork Nycolazs Android-Plus 1.2.0** (`com.lasrecomp.android`, base beta_5)

---

## Síntoma

La app se cierra sola al arrancar la pantalla de inicio o al tocar **JUGAR**. No hay excepción Java:
es un **crash nativo** (`data_app_native_crash`), siempre en el mismo punto y con el mismo backtrace.

Tombstone (`/data/tombstones/tombstone_08`, `_12`, `_16`; también en Android 13
`/data/tombstones`):

```
signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0000000000000000
Cause: null pointer dereference
pid: 4647, tid: 4734, name: SDLThread  >>> com.lasrecomp.android <<<

backtrace:
      #00 pc 000000000076a24c  /vendor/lib64/egl/libGLES_mali.so (BuildId: 209de09d564d4b78)
      #01 pc 0000000000769cec  /vendor/lib64/egl/libGLES_mali.so (BuildId: 209de09d564d4b78)
      #02 pc 000000000030987c  /data/app/.../lib/arm64/libmain.so (BuildId: eac275c0...)
      #03 pc 000000000031080c  /data/app/.../lib/arm64/libmain.so
      #04 pc 0000000000310880  /data/app/.../lib/arm64/libmain.so
      #05 pc 00000000000c167c  /apex/com.android.runtime/lib64/bionic/libc.so (__pthread_start)
```

Los offsets `0x30987c`, `0x31080c` y `0x310880` de `libmain.so` se repiten en **todos** los tombstone
del beta_6: el crash es determinista, no aleatorio.

En el log de la app (`lasrecomp.log`) las últimas líneas antes del SIGSEGV son:

```
[launcher] PLAY: waiting for the shader preparation
[pcore] big.LITTLE / hybrid CPU (cpu_capacity 336..1024): game threads on cores 4,5,6,7 (4 of 8)
```

En el arranque sin tocar JUGAR, el log termina en `[pcore] ...` y el proceso muere ~1-3 s después
(Dropbox: `data_app_native_crash`). La **preparación de shaders** del launcher (`prepare_shaders()` en
`runtime/ui/launcher.mm`, que llama a `shader_prep_run()`) crea pipelines que el driver r40p0 no tolera.

---

## Lo que NO es

| Hipótesis | Prueba | Resultado |
|---|---|---|
| `.ini` mal escrito | Log: `upscaler bilinear (chosen), resolution 50% (chosen)`; archivo sin comentarios inline | Descartado |
| Caché de pipelines/SPIR-V corrupta | Se renombró `cache/` entera y se arrancó limpio (caché nueva de 2.2 KB) | Crash idéntico |
| Video del launcher (`title.webm`) | Se reemplazó `title.webm` por un dummy del mismo tamaño (3.872.596 bytes); el launcher no decodifica video | Crash idéntico |
| Save corrupto | El crash ocurre antes de leer `save/save_0` | Descartado |
| Build del código del juego incompleto | `[gamebuild] done in 640s`, `[gamebuild] 93610 of 106472 functions cold (optnone)` | Descartado |
| Archivos del juego incompletos | `extracted/romfs`: 3836 archivos, 5.8 GB; el chequeo del launcher pasó al estar completos | Descartado |

El problema no está en la configuración ni en los archivos: es el **driver Mali**.

---

## Configuración aplicada (referencia)

El perfil que usa el repo (`profiles/larecomp-beta6-stability.ini`) deja:

```ini
aspect = original
resolution = 50%
dynamic_resolution = 1
dynamic_min = 360
fps_target = 30
upscaler = bilinear
antialias = off
shadows = off
ambient_occlusion = off
frame_interp = 0
```

Y el log confirma que se aplicó:

```
[settings] integrated GPU: upscaler bilinear (chosen), resolution 50% (chosen), dynamic, anti-aliasing off
```

No existe una línea del `.ini` que evite el SIGSEGV. Cualquier guía que diga “pon 25 % y se arregla”
no aplica a este crash: el driver se cae al crear el pipeline, antes de dibujar el juego.

---

## Texturas: el problema del fork

En el fork 1.2.0 (base beta_5), el log de gameplay mostraba:

```
[mem] heap write tracking off (a heap fault in an earlier run)
[vk] no page write tracking (-1, page 4096)
[vk] vertex cache off: no page write tracking
```

Esas líneas apagan el **page write tracking** que decide qué texturas volver a subir; la GPU puede leer
texturas viejas/negras. En beta_6/nightly, Mali usa **soft write tracking**, y el fix de texturas sin BC
evita las faltantes. Líneas que **no** son el fallo:

- `[vk] no BC texture formats: decoded on upload`: Mali-G57 no soporta BC1/BC3/BC7; se decodifican en
  CPU. Es una capacidad, no un error.
- `[nvn] texture 1x1 fmt 0x3f finalized while in 7 texture pool slot(s): emptied`: es una **protección**
  (`runtime/nvn/objects.c`): vacía slots para que una textura nueva no herede la vista vieja de otra
  (BC4/BC5/BC1 como RGBA8). No la desactives.

---

## Soluciones

1. **Nightly oficial 2026-11-17** (`c2e7e27`): app aparte `com.lasrecomp.android.nightly`. Incluye
   variantes de shaders nuevas (`#839`) y cambios ARM/Android. Es el primer candidato a evitar el
   pipeline que rompe el driver. Si sigue el mismo `libGLES_mali`, no alcanza.
2. **Fork Android-Plus 1.2.0** (beta_5): arranca en Mali-G57. Limitación: swapchain **FIFO**, que se
   cuelga ~30 s al perder el foco (por eso el perfil del fork usa 30 fps fijos y sin frame generation;
   además conviene no mandar la app a segundo plano).
3. **OTA de Unisoc/nubia** con un blob Mali más nuevo: la solución real. No hay driver instalable sin
   ROM/root para este T820.
4. **Build propio** con los defaults Mali desactivados. Los switches existen:
   `LARECOMP_VK_STRUCTURE=0`, `LARECOMP_VK_PUSH_CB=0`, `LARECOMP_VK_INLINE_C1=0`,
   `LARECOMP_VK_TINT_BRANCH=0`, `LARECOMP_VK_CS_FOLD=0`, `LARECOMP_VK_SPLIT_BARRIER=0`,
   `LARECOMP_VK_FAST_MINMAX=0`, `LARECOMP_VK_QUAD_DERIV=1`, `LARECOMP_VK_SPIRV_OPT=0`.
   En la APK release de Android **no** se pueden pasar por variable de entorno (`setprop wrap.*` está
   denegado en user build), así que hay que compilar o parchear el binario.

---

## Notas de plataforma

- **No hay backend OpenGL/GLES**: LAS Recomp es Vulkan.
- **Turnip es solo Adreno** (libadrenotools/kgsl). En Mali no se puede cargar.
- **PanVK** (Mesa Mali) es experimental y normalmente más lento que el blob de Arm en G57.
- **`lasgame.dll` de PC es x86-64 Windows**: no se puede cargar en Android ARM64. El `save` sí es
  portable; los archivos `exefs`/`romfs` son los mismos de la versión 1.0.0.

---

## Evidencia y pruebas

Los tombstone y logs completos están en el equipo de quien reportó; las pruebas se hicieron con
`adb`, `logcat`, `dumpsys dropbox`, `/data/tombstones` y capturas de pantalla. No se publican números
de serie, IPs ni datos personales.
