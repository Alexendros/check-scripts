# Tesis v0.5 · Ronda 001

**Rol**: IA-tesis (rol 01)
**Fecha**: 2026-05-20
**Artefacto canónico**: [`docs/tesis-v0.5.html`](../../docs/tesis-v0.5.html)

## Resumen

Tesis publicada como dossier visual en `docs/tesis-v0.5.html`. Define el
cluster XEK con 41 skills (+ SINTESIS) en 8 ámbitos:

- Foundation (3) · meta-forge · detecta-stack · orquesta
- Seguridad código (6) · sast · sca · dast · iac · integridad · datos-criticos
- Web genérico (4) · seo · a11y-web · perf-web · cookies
- Framework (6) · nextjs · vite · turbopack · react · astro · remix
- Compliance/Marca (3) · compliance-rgpd · compliance-licencias · marca
- Data (2) · db-sql · db-nosql
- Repo/Despliegue (2) · repo-higiene · despliegue
- Linux/Host (15) · fs · secretos · paquetes · actualizaciones · systemd ·
  seguridad · red · vpn · gpu · audio · bluetooth · energia · contenedores ·
  escritorio · backup

Doctrina · 12 invariantes (check-only, trifásica, agnóstica IA/operador/distro,
imperativa, canónica, migrable, append-only, componible, aplicable, dialéctica).

Linter `meta-forge` · 16 reglas (R1-R16). Workflow CI en
`.github/workflows/linter.yml` ejecuta R1-R7 + R15-R16.

## Decisiones de diseño documentadas

1. Cluster renombrado `SEC_*` → `XEK_*` para separar verificación de acción.
2. Composición en 3 capas: `depende_de:` declarativo, perfiles, `XEK_orquesta`.
3. Manifiesto v2 con `target_tipo: repo|app-en-vivo|host` y `host_huellas`.
4. Escalada agnóstica vía `${XEK_SUDO:-sudo -A}` en lugar de hardcodear `sudo`.
5. Metodología dialéctica con `ROSTER.yaml` separado del cuerpo.
6. 2 SKILL.md exemplares completos (XEK_sast, XEK_linux-gpu) + 39 stubs.

Para la versión completa con SVG y tabla matriz interactiva, abrir
[`docs/tesis-v0.5.html`](../../docs/tesis-v0.5.html) en navegador.
