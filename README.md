# LAS Recomp · Mali-G57 / Unisoc T820

Perfiles de configuración, diagnóstico del crash del driver Mali y actualizador automático para
**LAS Recomp** (el port/recompilación de *The Legend of Zelda: Link's Awakening*) en teléfonos
**ARM Mali-G57 MP4 / Unisoc T820** (probado en nubia Neo 2 5G, Android 13, driver `r40p0`).

> **Esto no es el juego ni un APK.** No contiene archivos del juego, claves (`prod.keys`/`title.keys`),
> saves, ROMs ni el APK de LAS Recomp. Necesitás tu propia copia legal del juego y la app oficial.
> Proyecto comunitario, no afiliado a Nintendo ni a los autores de LAS Recomp.

---

## Qué es y qué problema documenta

En el T820/Mali-G57, el **beta_6 oficial (v0.6.0)** se cierra al arrancar o al tocar JUGAR. No es el
`.ini`, no es el save y no es el video del launcher. El tombstone es determinista:

```
signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0
Cause: null pointer dereference
#00 libGLES_mali.so
#01 libGLES_mali.so
#02 libmain.so  (0x30987c)
#03 libmain.so  (0x31080c)
#04 libmain.so  (0x310880)
```

En el log de la app, las últimas líneas son:

```
[launcher] PLAY: waiting for the shader preparation
[pcore] big.LITTLE / hybrid CPU (cpu_capacity 336..1024): game threads on cores 4,5,6,7
```

Es un **null-dereference dentro del driver Mali r40p0** durante la preparación de shaders/pipelines.
El `.ini` sí se aplica (el log lo confirma):

```
[settings] integrated GPU: upscaler bilinear (chosen), resolution 50% (chosen), dynamic, anti-aliasing off
```

Por eso **ningún ajuste del `.ini` evita el cierre**. Lo que sí ayuda:

1. **Nightly oficial** posterior a beta_6 (`c2e7e27`, 2026-11-17): trae variantes de shaders nuevas y
   cambios ARM/Android; es el primer candidato a evitar el pipeline que rompe el driver.
2. **Fork Android-Plus 1.2.0** (beta_5): arranca en Mali-G57; a cambio tiene el cuelgue FIFO de ~30 s
   cuando la app pierde el foco (por eso el perfil del fork usa 30 fps fijos y sin frame generation).
3. **OTA de Unisoc/nubia** con un blob Mali más nuevo: la solución real del driver, si existe para tu modelo.
4. Build propio con los defaults Mali desactivados (`LARECOMP_VK_*`), que en la APK release no se pueden
   pasar por variable de entorno (el `wrap.` de Android está denegado).

El diagnóstico completo, con las pruebas que descartan caché, video, save y configuración, está en
[`docs/crash-mali-g57.md`](docs/crash-mali-g57.md).

---

## Perfiles incluidos

| Archivo | Para | Resolución | Upscaler | Extras |
|---|---|---|---|---|
| `profiles/larecomp-beta6-stability.ini` | beta_6 y **nightly** | 50 % (540p) + dinámica hasta 360p | Bilinear | 30 fps, sin AA/sombras/AO/FG, 16:9 |
| `profiles/larecomp-beta6-quality.ini` | Mali más rápida (G78/G710…) | 75 % fija (810p) | FSR 1 | 30 fps, sin AA/sombras/AO/FG |
| `profiles/larecomp-fork-stability.ini` | fork Nycolazs 1.2.0 | 50 % (540p) | Bilinear | 30 fps fijos, sin frame gen, Balanced |

**Regla de oro:** el parser de LAS Recomp lee **todo hasta el fin de línea** como valor. Nunca pongas
`# comentario` después de un valor:

```ini
resolution = 50%   # ESTO ROMPE: se interpreta como "50%   # ..." y cae a 4x
```

---

## Instalación

### Manual

1. Instalá **LAS Recomp** (beta_6, nightly o fork). Abrila una vez para que cree su carpeta de datos.
2. Copiá el perfil elegido como `larecomp.ini` en:

```
Android/data/com.lasrecomp.android/files/larecomp.ini          (beta_6 / fork)
Android/data/com.lasrecomp.android.nightly/files/larecomp.ini  (nightly)
```

3. Cerrá la app y volvé a abrirla. Listo.

### Automática (Windows + ADB)

```powershell
# beta_6 o fork:
.\scripts\apply-config.ps1 -Profile beta6 -Package com.lasrecomp.android

# nightly:
.\scripts\apply-config.ps1 -Profile beta6 -Package com.lasrecomp.android.nightly

# fork:
.\scripts\apply-config.ps1 -Profile fork -Package com.lasrecomp.android
```

El script hace backup del `larecomp.ini` actual en `backups/`, copia el perfil y reinicia la app.
Necesita `adb` en el PATH o el SDK de Android en la ruta por defecto.

### Linux / Termux

```bash
./scripts/apply-config.sh beta6 com.lasrecomp.android
./scripts/apply-config.sh beta6 com.lasrecomp.android.nightly
```

---

## Actualizaciones automáticas para los demás

**Cada `git push` a `main`** (que toque `profiles/`, `scripts/`, `docs/`, `README.md`, `LICENSE` o
`VERSION`) dispara GitHub Actions, que:

1. empaqueta `profiles/` + `scripts/` + `docs/` en `lasrecomp-mali-profiles.zip`;
2. genera su SHA-256;
3. crea una **Release nueva** (`v1.0.<número de ejecución>`) con esos archivos como assets.

Los usuarios solo tienen que ejecutar el actualizador:

```powershell
.\scripts\update.ps1 -Profile beta6 -Package com.lasrecomp.android
# o:
.\scripts\update.ps1 -Profile beta6 -Package com.lasrecomp.android.nightly
```

```bash
./scripts/update.sh beta6 com.lasrecomp.android
```

El script descarga el **último release** desde la URL fija:

```
https://github.com/joseestebanmarinrincones-dot/lasrecomp-mali-t820/releases/latest/download/lasrecomp-mali-profiles.zip
```

verifica el SHA-256, extrae y aplica el perfil. También podés suscribirte con **Watch → Custom →
Releases** para recibir aviso de cada versión.

**Importante:** esto actualiza **perfiles, scripts y documentación**. La app LAS Recomp en sí se
actualiza con el updater oficial de su repositorio (o reinstalando el APK/nightly). GitHub no puede
escribir en el teléfono de otra persona sin que esa persona ejecute un updater o instale la app.

---

## Cómo publicar una actualización

```bash
# editá profiles/, scripts/ o docs/
# opcional: cambiá VERSION
git add .
git commit -m "Perfil X: ajuste Y"
git push
```

GitHub Actions crea la Release automáticamente. El asset `lasrecomp-mali-profiles.zip` conserva el
mismo nombre en todos los releases, por eso la URL `releases/latest/download/...` siempre apunta a la
última versión.

---

## Estado y límites

- **beta_6 oficial v0.6.0**: crash determinista en `libGLES_mali` (ver arriba). No es configurable.
- **Nightly `c2e7e27` (2026-11-17)**: instalado como app aparte (`com.lasrecomp.android.nightly`),
  con variantes de shaders nuevas; es el candidato para saltar el pipeline que rompe el driver.
- **Fork Android-Plus 1.2.0**: arranca; el cuelgue FIFO al perder foco es su limitación conocida.
- **Driver**: Mali `v1.r40p0-01eac0.b0251c048237dcd59e6be15fba11a31a`, Vulkan 1.3.225.
- **No hay backend OpenGL**: LAS Recomp es solo Vulkan. **Turnip es solo Adreno**; en Mali no se puede
  cargar. **PanVK** (Mesa Mali) es experimental y más lento que el blob de Arm; no se recomienda para jugar.
- **Texturas**: Mali-G57 no soporta BC1/BC3/BC7; las texturas BC se decodifican en CPU. En el fork, el
  log muestra `[mem] heap write tracking off` y `[vk] no page write tracking`, que apaga los chequeos de
  subida y puede dejar texturas viejas/negras. beta_6/nightly usan soft write tracking en Mali.

Probado en: **nubia Neo 2 5G (Z2352N), Unisoc T820, Mali-G57 MP4, Android 13 (SDK 33), 7.3 GB RAM,
2400x1080**, con beta_6, nightly 2026-11-17 y fork 1.2.0.

---

## Privacidad y legal

- Este repo **no** incluye archivos del juego, claves, saves, ROMs, APKs ni logs con número de serie/IP.
- Los informes están saneados; no se publican datos personales.
- *The Legend of Zelda: Link's Awakening* es marca de Nintendo. Este proyecto no está afiliado ni
  patrocinado por Nintendo. Necesitás tu propia copia legal del juego.
- El código y la documentación de este repo son **MIT** (ver `LICENSE`). LAS Recomp es MIT de peiikai;
  el fork Android-Plus es MIT de Nycolazs. Las marcas y el juego pertenecen a sus dueños.

## Enlaces

- LAS Recomp oficial: https://github.com/peiikai/LASRecomp
- Nightly oficial: https://github.com/peiikai/LASRecomp/releases/tag/nightly
- Fork Android-Plus: https://github.com/Nycolazs/LASRecomp-Android-Plus
- Este repo: https://github.com/joseestebanmarinrincones-dot/lasrecomp-mali-t820
