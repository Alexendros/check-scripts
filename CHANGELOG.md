# Changelog

Todos los cambios destacables de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog 1.1.0](https://keepachangelog.com/es/1.1.0/),
y este proyecto se adhiere a [SemVer 2.0.0](https://semver.org/lang/es/).

## [Sin publicar]

### Añadido

- Testera `pytest` (`tests/`) con aislamiento total vía `tmp_path`, conformidad
  de manifiestos/findings contra JSON Schema y contrato reutilizable
  `RunnerContract`. Job `pytest` en CI.
- Runners ejecutables (oleada 1) que emiten `xek/finding@v1`: `XEK_repo-higiene`
  (repo) y `XEK_linux-fs` / `XEK_linux-actualizaciones` / `XEK_linux-backup`
  (host). Plantilla canónica `skills/_template/scripts/xek-skill-template.sh`.
- Runners ejecutables (oleada 2, host): `XEK_linux-contenedores`,
  `XEK_linux-energia`, `XEK_linux-escritorio`, `XEK_linux-peripherals` (con sus
  tests de contrato). `XEK_linux-peripherals` refina sus `checks[]` 001-005 a
  predicados pass/fail. Cobertura ejecutable del catálogo: 9 skills.
- Runners ejecutables (oleada 3, repo · seguridad/compliance): `XEK_sca`,
  `XEK_integridad`, `XEK_compliance-licencias`, `XEK_datos-criticos` (con sus
  tests de contrato). `XEK_sca` degrada a informativo si `osv-scanner` no está
  disponible. Cobertura ejecutable del catálogo: 13 skills.
- Runners ejecutables (oleada 4, repo · frameworks/build): `XEK_nextjs`,
  `XEK_vite`, `XEK_astro`, `XEK_remix` (con sus tests de contrato). Incorporan
  **compuerta de aplicabilidad**: si el framework no se detecta emiten
  `skipped:{razon:not_applicable}` y exit 0 (no-op limpio en repos ajenos).
  Cobertura ejecutable del catálogo: 17 skills.
- `xek/manifest@v2`: campo `host_huellas.distro_id` y gestores `poetry`,
  `bundler`, `composer`, `deno` en `repo.gestor_paquetes`.

### Cambiado

- `XEK_detecta-stack`: heurísticas validadas contra herramientas profesionales
  (audio pipewire≠pulseaudio, precedencia `ID`/`ID_LIKE` de os-release, `bun.lock`,
  GPU vía `/sys/class/drm`, frameworks `@sveltejs/kit`/`nuxt`/`gatsby`/`expo`).
- Los `SKILL.md` con runner dejan de duplicar el bash (single source of truth).
- `shellcheck` pasa a ser bloqueante en CI.

### Corregido

- `XEK_detecta-stack` modo `real`: el gate creaba su propio sandbox antes de
  comprobarlo y siempre pasaba; ahora exige un sandbox previo real.

## [0.1.0] — 2026-MM-DD

### Añadido

- Versión inicial del repositorio con canon de documentación aplicado.

[Sin publicar]: https://github.com/alexendros/xek-cluster/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alexendros/xek-cluster/releases/tag/v0.1.0
