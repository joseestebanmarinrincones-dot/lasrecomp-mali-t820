#!/usr/bin/env bash
# Descarga el ultimo release, verifica SHA-256 y aplica el perfil por ADB.
# Uso: ./update.sh [beta6|fork|quality] [package]
set -euo pipefail

PROFILE="${1:-beta6}"
PACKAGE="${2:-com.lasrecomp.android}"
REPO="${REPO:-joseestebanmarinrincones-dot/lasrecomp-mali-t820}"

URL="https://github.com/$REPO/releases/latest/download/lasrecomp-mali-profiles.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Descargando $URL"
curl -fL --retry 3 --connect-timeout 20 -o "$TMP/lasrecomp-mali-profiles.zip" "$URL"
curl -fL --retry 3 --connect-timeout 20 -o "$TMP/lasrecomp-mali-profiles.zip.sha256" "$URL.sha256" || true

if [ -f "$TMP/lasrecomp-mali-profiles.zip.sha256" ]; then
  ( cd "$TMP" && sha256sum -c lasrecomp-mali-profiles.zip.sha256 )
else
  echo "Aviso: el release no trae SHA-256; sigo sin verificar." >&2
fi

mkdir -p "$TMP/files"
unzip -q "$TMP/lasrecomp-mali-profiles.zip" -d "$TMP/files"

if [ ! -f "$TMP/files/scripts/apply-config.sh" ]; then
  echo "El release no trae scripts/apply-config.sh" >&2
  exit 7
fi

bash "$TMP/files/scripts/apply-config.sh" "$PROFILE" "$PACKAGE"
