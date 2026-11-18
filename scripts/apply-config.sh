#!/usr/bin/env bash
# Aplica un perfil de LAS Recomp por ADB (Linux, macOS, Termux).
# Uso: ./apply-config.sh [beta6|fork|quality] [package]
set -euo pipefail

PROFILE="${1:-beta6}"
PACKAGE="${2:-com.lasrecomp.android}"
ADB="${ADB:-adb}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

case "$PROFILE" in
  beta6)   FILE="larecomp-beta6-stability.ini" ;;
  fork)    FILE="larecomp-fork-stability.ini" ;;
  quality) FILE="larecomp-beta6-quality.ini" ;;
  *) echo "Perfil desconocido: $PROFILE (beta6|fork|quality)" >&2; exit 2 ;;
esac

SRC="$ROOT/profiles/$FILE"
DEST="/sdcard/Android/data/$PACKAGE/files/larecomp.ini"
BACKUP_DIR="$ROOT/backups"

if ! command -v "$ADB" >/dev/null 2>&1; then
  echo "No encuentro adb. Instala platform-tools o exporta ADB=/ruta/adb" >&2
  exit 3
fi
if [ ! -f "$SRC" ]; then
  echo "No encuentro el perfil: $SRC" >&2
  exit 4
fi
if ! "$ADB" devices | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
  echo "No hay telefono autorizado en 'adb devices'. Acepta la depuracion USB." >&2
  exit 5
fi

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
if "$ADB" pull "$DEST" "$BACKUP_DIR/larecomp-$PACKAGE-$STAMP.ini" >/dev/null 2>&1; then
  echo "Backup: $BACKUP_DIR/larecomp-$PACKAGE-$STAMP.ini"
else
  echo "No habia larecomp.ini previo (o no se pudo leer); sigo."
fi

"$ADB" shell "am force-stop $PACKAGE" >/dev/null
"$ADB" push "$SRC" "$DEST" >/dev/null
if [ "$?" -ne 0 ]; then
  echo "adb push fallo. Verifica que la app este instalada y exista Android/data/$PACKAGE/files." >&2
  exit 6
fi

ACTIVITY="$("$ADB" shell "cmd package resolve-activity --brief $PACKAGE" 2>/dev/null | tr -d '\r' | grep '/' | tail -n1 || true)"
if [ -n "$ACTIVITY" ]; then
  "$ADB" shell "am start -n $ACTIVITY" >/dev/null || true
fi

echo "Perfil '$PROFILE' aplicado a $PACKAGE."
