# Changelog

## v1.0.3 — 2026-11-18

- `docs/session-2026-11-18.md`: estado del setup del nightly (archivos 3836, perfil,
  save de PC, build del código del juego) y resultado pendiente del test.
- `CHANGELOG.md`: historial de versiones.
- README: enlace al estado actual.

## v1.0.2 — 2026-11-18

- `scripts/update.ps1`: corrige la lectura del asset `.sha256` (en Windows PowerShell
  llega como `byte[]` y `.Trim()` fallaba).
- Release publicada automáticamente por GitHub Actions.

## v1.0.1 — 2026-11-18

- Primera publicación: perfiles beta_6/nightly y fork, guía del crash Mali-G57,
  scripts de aplicación y updater.
- Workflow `release.yml`: cada push a `main` crea una Release con el ZIP fijo
  `lasrecomp-mali-profiles.zip` y su SHA-256.
